import Foundation

public struct TkSharpEngine: MergingEngine {
    public static let executableName = "graft-merge"

    public let executable: URL
    public let settings: GraftSettings
    public let paths: GraftPaths

    public init(executable: URL, settings: GraftSettings, paths: GraftPaths) {
        self.executable = executable
        self.settings = settings
        self.paths = paths
    }

    static func locate() -> URL? {
        var candidates = [Bundle.main.bundleURL.appending(path: "Contents/Helpers/\(executableName)")]
        if let executable = Bundle.main.executableURL?.resolvingSymlinksInPath() {
            candidates.append(executable.deletingLastPathComponent().appending(path: executableName))
        }
        #if DEBUG
        candidates.append(URL(fileURLWithPath: #filePath).appending(path: "../../../../.build/app/helper/\(executableName)").standardizedFileURL)
        #endif
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    struct HelperConfig: Encodable {
        struct OtherGame: Encodable {
            let name: String
            let extensions: [String]
            let folders: [String]
        }

        let dataFolder: String
        let keysFolder: String
        let baseGame: String
        let update: String
        let language: String
        let titleText: String
        let gameName: String
        let otherGames: [OtherGame]
        let setup: [SetupEntry]?
    }

    struct SetupEntry: Encodable {
        let id: String
        let enabled: Bool
        let options: [String: [String]]
    }

    struct HelperFailure: Decodable {
        let error: String
    }

    struct HelperEvent: Decodable {
        let event: String
        let message: String
    }

    func writeConfig(setup: [InstalledMod]? = nil, to file: URL) throws {
        let game = settings.definition
        let config = HelperConfig(
            dataFolder: paths.support.path,
            keysFolder: settings.general.keysFolder,
            baseGame: settings.game.baseGame,
            update: settings.game.update,
            language: GameLanguage.resolve(settings.game.language, for: settings),
            titleText: game.supportsTitleText ? settings.game.titleText : "",
            gameName: game.name,
            otherGames: KnownGame.others(than: game, catalog: .shared, templates: .shared).map {
                HelperConfig.OtherGame(name: $0.name, extensions: $0.signatures.extensions, folders: $0.signatures.folders)
            },
            setup: setup?.map { SetupEntry(id: $0.id, enabled: $0.enabled, options: $0.selectedOptions) })
        try JSONFile.write(config, to: file)
    }

    func call<T: Decodable & Sendable>(_ type: T.Type, _ arguments: [String], setup: [InstalledMod]? = nil,
                                       progress: @escaping @Sendable (String) -> Void = { _ in }) async throws -> T {
        let config = paths.helperConfig(id: UUID())
        try writeConfig(setup: setup, to: config)
        defer { try? FileManager.default.removeItem(at: config) }
        let result = try await ProcessRunner.run(executable, arguments: ["--config", config.path] + arguments) { line in
            if let event = try? JSONDecoder().decode(HelperEvent.self, from: Data(line.utf8)), event.event == "progress" {
                progress(event.message)
            }
        }
        let decoder = JSONDecoder()
        guard result.status == 0 else {
            if let failure = try? decoder.decode(HelperFailure.self, from: result.output) {
                throw GraftError(failure.error)
            }
            throw GraftError("The merge helper stopped unexpectedly (exit \(result.status)): \(result.errorText.suffix(400))")
        }
        do {
            return try decoder.decode(T.self, from: result.output)
        } catch {
            throw GraftError("The merge helper returned something unexpected: \(result.outputText.prefix(400))")
        }
    }

    public func list() async throws -> [InstalledMod] {
        try await call(ModList.self, ["list"]).mods
    }

    public func add(_ path: URL, progress: @escaping @Sendable (String) -> Void) async throws -> AddedMod {
        let result = try await call(InstallResult.self, ["install", path.path], progress: progress)
        let name = result.mods.first { $0.id == result.installed }?.displayName ?? path.lastPathComponent
        return AddedMod(id: result.installed, name: name, replacedIds: result.replacedIds, keptCodeBuilds: result.keptCodeBuilds, warnings: result.warnings, mods: result.mods)
    }

    public func remove(_ id: String) async throws -> [InstalledMod] {
        try await call(ModList.self, ["uninstall", id]).mods
    }

    public func merge(_ mods: [InstalledMod], into folder: URL, progress: @escaping @Sendable (String) -> Void) async throws -> MergeReport {
        try await call(MergeReport.self, ["merge", folder.path], setup: mods, progress: progress)
    }

    public func apply(_ mods: [InstalledMod], force: Bool, stage: @escaping @Sendable (ApplyStage) -> Void) async throws -> ApplyOutcome {
        try await Applier(settings: settings, engine: self, paths: paths).apply(mods, force: force, stage: stage)
    }

    public func readCodePatch(_ file: URL) async throws -> CodePatchFile {
        try await call(CodePatchFile.self, ["read-patch", file.path])
    }

    public func updateVersions(of files: [URL]) async throws -> [UpdateFile] {
        guard !files.isEmpty else { return [] }
        return try await call(UpdateList.self, ["identify-updates"] + files.map(\.path)).updates
    }

    public func importableLibrary() -> ImportableLibrary? {
        let tkmm = LibraryImport(paths: paths)
        guard tkmm.libraryIsEmpty, let location = tkmm.findTKMMLibrary() else { return nil }
        return ImportableLibrary(manager: "TKMM", location: location)
    }

    public func importLibrary(_ library: ImportableLibrary) async throws -> URL? {
        try await FileLock.holding(paths.libraryLock) {
            try LibraryImport(paths: paths).importTKMM(from: library.location)
        }
    }
}
