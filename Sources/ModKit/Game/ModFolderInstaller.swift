import Foundation

public struct ModFolderInstaller: Sendable {
    public let settings: GraftSettings
    public let version: String
    public let paths: GraftPaths

    public init(settings: GraftSettings, version: String, paths: GraftPaths) {
        self.settings = settings
        self.version = version
        self.paths = paths
    }

    public var target: URL { paths.modsFolder(version: version) }
    public var staging: URL { target.deletingLastPathComponent().appending(path: "\(version).incoming", directoryHint: .isDirectory) }

    public func install(romfs: URL?) async throws -> String {
        let fm = FileManager.default
        try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)

        guard let romfs, fm.fileExists(atPath: romfs.path) else {
            return (["No data mods are on."] + (try clear())).joined(separator: " ")
        }
        guard let relative = settings.definition.tkSharp?.manifestScript else {
            throw GraftError("MacNativeGames has no way to install \(settings.definition.name) mods yet.")
        }

        try? fm.removeItem(at: staging)
        try fm.copyItem(at: romfs, to: staging)
        defer { try? fm.removeItem(at: staging) }
        let result = try await MacNativeGames(settings).run(
            relative, arguments: [staging.path, "--app", settings.game.gameApp, "--version", version])
        if result.status != 0 {
            if result.errorText.contains(MacNativeGames.nothingToInstall) {
                return (["The data mods change nothing the game app doesn't already provide."] + (try clear())).joined(separator: " ")
            }
            throw GraftError("Writing the mod folder's manifest failed: \(result.lastLines(2))")
        }

        let notes = try place(staging)
        return (["Installed data mods: \(Self.summary(ofManifest: target.appending(path: "manifest.tsv")))."] + notes).joined(separator: " ")
    }

    public func place(_ folder: URL) throws -> [String] {
        let notes = try makeRoom(at: target)
        try FileManager.default.moveItem(at: folder, to: target)
        try markManaged(target)
        return notes
    }

    public func clear() throws -> [String] {
        try makeRoom(at: target)
    }

    func makeRoom(at target: URL) throws -> [String] {
        let fm = FileManager.default
        defer { try? fm.removeItem(at: marker) }
        guard fm.fileExists(atPath: target.path) else { return [] }
        if isManaged(target) {
            try fm.removeItem(at: target)
            return []
        }
        let backup = BackupName.unused(in: target.deletingLastPathComponent(), prefix: "\(version).backup")
        try fm.moveItem(at: target, to: backup)
        return ["Your earlier mod folder was moved to \(backup.path)."]
    }

    static func summary(ofManifest manifest: URL) -> String {
        let lines = ((try? String(contentsOf: manifest, encoding: .utf8)) ?? "")
            .split(whereSeparator: \.isNewline).filter { !$0.hasPrefix("#") }
        let added = lines.filter { $0.split(separator: "\t").last == "-" }.count
        return "\(counted(lines.count, "file")) (\(lines.count - added) replaced, \(added) added)"
    }

    var marker: URL {
        target.deletingLastPathComponent().appending(path: ".\(version).managed-by-graft")
    }

    static func fingerprint(of folder: URL) -> String? {
        guard let enumerator = FileManager.default.enumerator(atPath: folder.path) else { return nil }
        var lines: [String] = []
        while let relative = enumerator.nextObject() as? String {
            guard !isSystemFile(relative),
                  let attributes = enumerator.fileAttributes, attributes[.type] as? FileAttributeType == .typeRegular else { continue }
            let size = (attributes[.size] as? NSNumber)?.int64Value ?? 0
            let modified = (attributes[.modificationDate] as? Date)?.timeIntervalSinceReferenceDate ?? 0
            lines.append("\(relative)\t\(size)\t\(modified)")
        }
        guard !lines.isEmpty else { return nil }
        return Hashing.sha256(Data(lines.sorted().joined(separator: "\n").utf8))
    }

    static func isSystemFile(_ relative: String) -> Bool {
        let parts = relative.split(separator: "/")
        guard let name = parts.last else { return false }
        return name.hasPrefix("._") || [".DS_Store", "Thumbs.db", "desktop.ini"].contains(name) || parts.contains("__MACOSX")
    }

    func isManaged(_ folder: URL) -> Bool {
        guard let recorded = try? String(contentsOf: marker, encoding: .utf8),
              let fingerprint = Self.fingerprint(of: folder) else { return false }
        return recorded.trimmingCharacters(in: .whitespacesAndNewlines) == fingerprint
    }

    func markManaged(_ folder: URL) throws {
        guard let fingerprint = Self.fingerprint(of: folder) else { return }
        try (fingerprint + "\n").write(to: marker, atomically: true, encoding: .utf8)
    }
}
