import Foundation

public struct FileModEngine: ModEngine {
    static let pakExtensions: Set<String> = ["pak", "utoc", "ucas", "sig"]

    struct Record: Codable, Sendable {
        var id: String
        var name: String
        var enabled: Bool
        var files: Int
    }

    public let settings: GraftSettings
    public let paths: GraftPaths
    let fileMods: FileModSettings
    var otherGames: [KnownGame] = []

    var recordsFile: URL { paths.library.appending(path: "mods.json") }

    func records() throws -> [Record] {
        try JSONFile.read([Record].self, from: recordsFile) ?? []
    }

    func save(_ records: [Record]) throws {
        try JSONFile.write(records, to: recordsFile)
    }

    func mods(_ records: [Record]) -> [InstalledMod] {
        records.enumerated().map { position, record in
            InstalledMod(id: record.id, name: record.name, version: "", author: "", description: "", enabled: record.enabled,
                         position: position, dataFiles: record.files, textFiles: 0, subSdkFiles: 0, cheatFiles: 0,
                         codePatchBuilds: [], optionGroups: [])
        }
    }

    func editing(_ change: (inout [Record]) throws -> Void) async throws -> [InstalledMod] {
        try await FileLock.holding(paths.libraryLock) {
            var records = try records()
            try change(&records)
            try save(records)
            return mods(records)
        }
    }

    public func list() async throws -> [InstalledMod] {
        mods(try records())
    }

    public func add(_ path: URL, progress: @escaping @Sendable (String) -> Void) async throws -> AddedMod {
        let fm = FileManager.default
        let incoming = paths.library.appending(path: ".incoming-\(UUID().uuidString)", directoryHint: .isDirectory)
        try fm.createDirectory(at: incoming, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: incoming) }

        progress("Reading \(path.lastPathComponent)")
        let unpacked = incoming.appending(path: "unpacked", directoryHint: .isDirectory)
        try await unpack(path, into: unpacked)
        let content = incoming.appending(path: "content", directoryHint: .isDirectory)
        let romfs = content.appending(path: "romfs", directoryHint: .isDirectory)
        try fm.createDirectory(at: content, withIntermediateDirectories: true)
        if let found = Self.folders(named: "romfs", in: unpacked).first {
            try fm.moveItem(at: found, to: romfs)
        } else {
            let paks = Self.files(in: unpacked).filter { Self.pakExtensions.contains($0.pathExtension.lowercased()) }
            guard !paks.isEmpty else {
                throw GraftError("\(path.lastPathComponent) has no romfs folder and no .pak files, so there's nothing in it for \(settings.definition.name).")
            }
            let target = romfs.appending(path: fileMods.pakFolder, directoryHint: .isDirectory)
            try fm.createDirectory(at: target, withIntermediateDirectories: true)
            for pak in paks {
                try fm.moveItem(at: pak, to: target.appending(path: pak.lastPathComponent))
            }
        }
        if let owner = KnownGame.owner(of: Self.relativeFiles(in: romfs), addedTo: settings.definition, among: otherGames) {
            throw GraftError("'\(Self.modName(of: path))' is a \(owner.name) mod, so it can't be added to \(settings.definition.name).")
        }
        var warnings: [String] = []
        if !Self.folders(named: "exefs", in: unpacked).isEmpty || !Self.folders(named: "cheats", in: unpacked).isEmpty {
            warnings.append("Its code patches and cheats aren't supported for \(settings.definition.name) yet, so only its game files are added.")
        }

        let name = Self.modName(of: path)
        let files = Self.files(in: romfs).count
        let id = UUID().uuidString
        var replaced: [String] = []
        let mods = try await editing { records in
            try fm.moveItem(at: content, to: paths.library.appending(path: id, directoryHint: .isDirectory))
            let others = records.filter { $0.name == name }
            let record = Record(id: id, name: name, enabled: others.first?.enabled ?? true, files: files)
            if let place = records.firstIndex(where: { $0.name == name }) {
                records[place] = record
                records.removeAll { $0.name == name && $0.id != id }
                for other in others {
                    try? fm.removeItem(at: paths.library.appending(path: other.id, directoryHint: .isDirectory))
                }
                replaced = others.map(\.id)
            } else {
                records.append(record)
            }
        }
        return AddedMod(id: id, name: name, replacedIds: replaced, keptCodeBuilds: [], warnings: warnings, mods: mods)
    }

    public func remove(_ id: String) async throws -> [InstalledMod] {
        try await editing { records in
            records.removeAll { $0.id == id }
            try? FileManager.default.removeItem(at: paths.library.appending(path: id, directoryHint: .isDirectory))
        }
    }

    public func apply(_ mods: [InstalledMod], force: Bool, stage: @escaping @Sendable (ApplyStage) -> Void) async throws -> ApplyOutcome {
        try await FileLock.holding(paths.applyLock) {
            try await applyHoldingLock(mods, stage: stage)
        }
    }

    private func applyHoldingLock(_ mods: [InstalledMod], stage: @escaping @Sendable (ApplyStage) -> Void) async throws -> ApplyOutcome {
        let fm = FileManager.default
        if GameEnvironment.isGameRunning(settings) {
            throw GraftError(GameEnvironment.quitFirstMessage)
        }
        let enabled = mods.filter(\.enabled)
        let version = try gameVersion()
        let installer = ModFolderInstaller(settings: settings, version: version, paths: paths)
        try fm.createDirectory(at: installer.target.deletingLastPathComponent(), withIntermediateDirectories: true)
        let staging = installer.staging
        try? fm.removeItem(at: staging)
        defer { try? fm.removeItem(at: staging) }

        let summary: String
        if enabled.isEmpty {
            summary = (["No mods are on."] + (try installer.clear())).joined(separator: " ")
        } else {
            stage(.merging("Combining \(counted(enabled.count, "mod"))"))
            for mod in enabled.reversed() {
                try Self.copy(paths.library.appending(path: "\(mod.id)/romfs", directoryHint: .isDirectory), over: staging)
            }
            stage(.installingData)
            try await writeManifest(staging, version: version)
            let notes = try installer.place(staging)
            summary = (["Installed data mods: \(ModFolderInstaller.summary(ofManifest: installer.target.appending(path: "manifest.tsv")))."] + notes)
                .joined(separator: " ")
        }

        var state = ApplyState.load(from: paths)
        state.appliedModsDigest = Applier.digest(of: mods, settings: settings, buildId: (try? GameLayout.load(for: settings))?.buildId)
        try state.save(to: paths)
        return ApplyOutcome(rebuilt: false, codeAtLaunch: false, statuses: [], ignored: [], dataSummary: summary, mods: mods)
    }

    func gameVersion() throws -> String {
        settings.definition.versionFolder(forDisplayVersion: try AppBundle.requireShortVersion(at: settings.game.gameApp))
    }

    func writeManifest(_ romfs: URL, version: String) async throws {
        let gameRomfs = URL(fileURLWithPath: settings.game.gameApp)
            .appending(path: "\(fileMods.appGameFolder)/extracted/\(version)/romfs", directoryHint: .isDirectory)
        let result = try await MacNativeGames(settings).run(fileMods.manifestScript, arguments: [romfs.path, "--romfs", gameRomfs.path])
        guard result.status == 0 else {
            throw GraftError("Writing the mod folder's manifest failed: \(result.lastLines(2))")
        }
    }

    func unpack(_ source: URL, into folder: URL) async throws {
        let fm = FileManager.default
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: source.path, isDirectory: &isDirectory) else {
            throw GraftError("\(source.path) does not exist.")
        }
        if isDirectory.boolValue {
            try fm.copyItem(at: source, to: folder)
            return
        }
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        if Self.pakExtensions.contains(source.pathExtension.lowercased()) {
            try fm.copyItem(at: source, to: folder.appending(path: source.lastPathComponent))
            return
        }
        let result = try await ProcessRunner.run(URL(fileURLWithPath: "/usr/bin/bsdtar"), arguments: ["-xf", source.path, "-C", folder.path])
        guard result.status == 0 else {
            throw GraftError("\(source.lastPathComponent) couldn't be unpacked: \(result.errorText.trimmingCharacters(in: .whitespacesAndNewlines))")
        }
    }

    static func modName(of path: URL) -> String {
        let isFolder = path.hasDirectoryPath || (try? path.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        let base = isFolder ? path.lastPathComponent : path.deletingPathExtension().lastPathComponent
        return base.replacing(/-\d+(-\d+)*$/, with: "").trimmingCharacters(in: .whitespaces)
    }

    static func files(in folder: URL) -> [URL] {
        relativeFiles(in: folder).map { folder.appending(path: $0) }
    }

    static func relativeFiles(in folder: URL) -> [String] {
        guard let enumerator = FileManager.default.enumerator(atPath: folder.path) else { return [] }
        var files: [String] = []
        while let relative = enumerator.nextObject() as? String {
            guard !ModFolderInstaller.isSystemFile(relative), enumerator.fileAttributes?[.type] as? FileAttributeType == .typeRegular else { continue }
            files.append(relative)
        }
        return files
    }

    static func folders(named name: String, in folder: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(atPath: folder.path) else { return [] }
        var found: [String] = []
        while let relative = enumerator.nextObject() as? String {
            guard !ModFolderInstaller.isSystemFile(relative), enumerator.fileAttributes?[.type] as? FileAttributeType == .typeDirectory,
                  (relative as NSString).lastPathComponent.lowercased() == name else { continue }
            found.append(relative)
        }
        return found.sorted { $0.split(separator: "/").count < $1.split(separator: "/").count }.map { folder.appending(path: $0) }
    }

    static func copy(_ source: URL, over target: URL) throws {
        let fm = FileManager.default
        for relative in relativeFiles(in: source) {
            let destination = target.appending(path: relative)
            try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            if fm.fileExists(atPath: destination.path) { try fm.removeItem(at: destination) }
            try fm.copyItem(at: source.appending(path: relative), to: destination)
        }
    }
}
