import Foundation

public struct ApplyOutcome: Sendable {
    public let rebuilt: Bool
    public let codeAtLaunch: Bool
    public let statuses: [ModCodeStatus]
    public let ignored: [IgnoredCode]
    public let dataSummary: String
    public let mods: [InstalledMod]
}

public enum ApplyStage: Sendable {
    case merging(String)
    case checkingCode
    case rebuilding(BuildPlan)
    case building(String)
    case installingData
}

public struct ApplySteps: Sendable {
    public var isGameRunning: @Sendable () async -> Bool
    public var loadLayout: @Sendable () throws -> GameLayout
    public var reservedSites: @Sendable (GameLayout) async throws -> [ReservedSite]
    public var build: @Sendable (_ modFolder: URL?, _ progress: @escaping @Sendable (String) -> Void) async throws -> Void
    public var installData: @Sendable (_ romfs: URL?, _ layout: GameLayout) async throws -> String

    public init(isGameRunning: @escaping @Sendable () async -> Bool,
                loadLayout: @escaping @Sendable () throws -> GameLayout,
                reservedSites: @escaping @Sendable (GameLayout) async throws -> [ReservedSite],
                build: @escaping @Sendable (URL?, @escaping @Sendable (String) -> Void) async throws -> Void,
                installData: @escaping @Sendable (URL?, GameLayout) async throws -> String) {
        self.isGameRunning = isGameRunning
        self.loadLayout = loadLayout
        self.reservedSites = reservedSites
        self.build = build
        self.installData = installData
    }

    public static func live(settings: GraftSettings, paths: GraftPaths) -> ApplySteps {
        ApplySteps(
            isGameRunning: { GameEnvironment.isGameRunning(settings) },
            loadLayout: { try GameLayout.load(for: settings) },
            reservedSites: { try await GameEnvironment.reservedSites(settings: settings, layout: $0) },
            build: { try await GameBuilder(settings: settings).build(modFolder: $0, progress: $1) },
            installData: { try await ModFolderInstaller(settings: settings, version: $1.version, paths: paths).install(romfs: $0) }
        )
    }
}

public struct Applier: Sendable {
    public let settings: GraftSettings
    public let engine: any MergingEngine
    public let paths: GraftPaths
    public let steps: ApplySteps

    public init(settings: GraftSettings, engine: any MergingEngine, paths: GraftPaths, steps: ApplySteps? = nil) {
        self.settings = settings
        self.engine = engine
        self.paths = paths
        self.steps = steps ?? .live(settings: settings, paths: paths)
    }

    public func apply(_ mods: [InstalledMod], force: Bool = false,
                      stage: @escaping @Sendable (ApplyStage) -> Void) async throws -> ApplyOutcome {
        try await FileLock.holding(paths.applyLock) {
            try await applyHoldingLock(mods, force: force, stage: stage)
        }
    }

    private func applyHoldingLock(_ mods: [InstalledMod], force: Bool, stage: @escaping @Sendable (ApplyStage) -> Void) async throws -> ApplyOutcome {
        let fm = FileManager.default
        let game = settings.definition
        if let reason = game.unsupportedReason {
            throw GraftError(reason)
        }
        if await steps.isGameRunning() {
            throw GraftError(GameEnvironment.quitFirstMessage)
        }
        let layout = try steps.loadLayout()
        var state = ApplyState.load(from: paths)
        let enabled = mods.filter(\.enabled)

        let merged = paths.merged
        let report: MergeReport?
        if enabled.isEmpty {
            try? fm.removeItem(at: merged)
            report = nil
        } else {
            stage(.merging("Merging \(counted(enabled.count, "mod"))"))
            let merge = try await engine.merge(mods, into: merged) { message in stage(.merging(message)) }
            guard merge.buildId.lowercased() == layout.buildId.lowercased() else {
                throw GraftError("The update file chosen for this game is for a different version than the game app (\(layout.displayVersion)). Choose the \(layout.displayVersion) update in Game Info, or build the game app again for the update you have.")
            }
            report = merge
        }

        stage(.checkingCode)
        let reserved = report?.codePatches.isEmpty == false
            ? try await steps.reservedSites(layout) : []
        let composed = try report.map { try PatchComposer.compose(report: $0, layout: layout, reserved: reserved) }
        let codeDigest = composed.flatMap { $0.isEmpty ? nil : $0.digest }
        let heapTable = game.tkSharp?.codeMods?.heapTable
        var heapDigest: String?
        if report != nil, let heapTable, fm.fileExists(atPath: merged.appending(path: "romfs/\(heapTable)").path) {
            heapDigest = try Hashing.sha256(of: merged.appending(path: "romfs/\(heapTable)"))
        }
        let appHeapDigest = builtHeapDigest(layout: layout)

        let needsRewriter = composed?.statuses.contains { status in
            if case .unfixable = status.analysis.outcome { return false }
            return !status.analysis.unsupportedInstructions.isEmpty
        } ?? false
        let plan = BuildPlan.decide(
            codeDigest: codeDigest, needsRewriter: needsRewriter,
            appSupportsCodeAtLaunch: Self.supportsCodeAtLaunch(settings: settings),
            builtCodeDigest: state.builtCode[settings.game.gameApp], heapDigest: heapDigest, appHeapDigest: appHeapDigest, force: force)
        if plan.needsBuild {
            let input = paths.buildInput
            try? fm.removeItem(at: input)
            var modFolder: URL?
            if let composed, plan.bakedCode != nil {
                try fm.createDirectory(at: input.appending(path: "exefs"), withIntermediateDirectories: true)
                try composed.pchtxt.write(to: input.appending(path: "exefs/mods.pchtxt"), atomically: true, encoding: .utf8)
                modFolder = input
            }
            if let heapTable, heapDigest != nil {
                let target = input.appending(path: "romfs/\(heapTable)")
                try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fm.copyItem(at: merged.appending(path: "romfs/\(heapTable)"), to: target)
                modFolder = input
            }
            stage(.rebuilding(plan))
            try await steps.build(modFolder) { line in stage(.building(line)) }
            state.builtCode[settings.game.gameApp] = plan.bakedCode
            try state.save(to: paths)
        }

        try? fm.removeItem(at: paths.codePatch)
        if plan.codeAtLaunch, let composed {
            try fm.createDirectory(at: paths.support, withIntermediateDirectories: true)
            try composed.pchtxt.write(to: paths.codePatch, atomically: true, encoding: .utf8)
        }
        state.codeAtLaunch = plan.codeAtLaunch
        try state.save(to: paths)

        stage(.installingData)
        let romfs = merged.appending(path: "romfs")
        let summary = try await steps.installData(report != nil && fm.fileExists(atPath: romfs.path) ? romfs : nil, layout)

        state.recordOwners(composed?.owners ?? [:])
        state.appliedModsDigest = Self.digest(of: mods, settings: settings, buildId: layout.buildId)
        state.codeStatus = Dictionary(uniqueKeysWithValues: (composed?.statuses ?? []).map { ($0.modId, CodeStatus($0.analysis.outcome)) })
        try state.save(to: paths)

        return ApplyOutcome(rebuilt: plan.needsBuild, codeAtLaunch: plan.codeAtLaunch, statuses: composed?.statuses ?? [], ignored: report?.ignoredCode ?? [],
                            dataSummary: summary, mods: mods)
    }

    private struct DefinitionInputs: Encodable {
        let mods: ModSupport
        let dataFolder: String?
        let workTree: String
        let versionFolders: GameDefinition.VersionFolders?
    }

    public static func digest(of mods: [InstalledMod], settings: GraftSettings, buildId: String?) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        var data = (try? encoder.encode(mods)) ?? Data()
        let game = settings.definition
        let definition = DefinitionInputs(mods: game.mods, dataFolder: game.dataFolder, workTree: game.workTreeName, versionFolders: game.versionFolders)
        data.append((try? encoder.encode(definition)) ?? Data())
        let inputs = [
            GameLanguage.resolve(settings.game.language, for: settings), settings.game.titleText,
            String(supportsCodeAtLaunch(settings: settings)), buildId ?? "",
            settings.game.gameApp, settings.game.baseGame, settings.game.update,
        ]
        data.append(Data(inputs.joined(separator: "|").utf8))
        return Hashing.sha256(data)
    }

    public static func supportsCodeAtLaunch(settings: GraftSettings) -> Bool {
        guard let file = settings.definition.tkSharp?.codeMods?.buildIdFile else { return false }
        let extracted = extractedFolder(settings)
        guard let versions = try? FileManager.default.contentsOfDirectory(atPath: extracted.path) else { return false }
        return versions.contains { FileManager.default.fileExists(atPath: extracted.appending(path: "\($0)/\(file)").path) }
    }

    static func extractedFolder(_ settings: GraftSettings) -> URL {
        URL(fileURLWithPath: settings.game.gameApp).appending(path: "Contents/Resources/\(settings.definition.workTreeName)/extracted")
    }

    func builtHeapDigest(layout: GameLayout) -> String? {
        guard let heapRecord = settings.definition.tkSharp?.codeMods?.heapRecord else { return nil }
        let record = Self.extractedFolder(settings).appending(path: "\(layout.version)/\(heapRecord)")
        guard let data = try? Data(contentsOf: record),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return json["heapdef_sha256"] as? String
    }
}
