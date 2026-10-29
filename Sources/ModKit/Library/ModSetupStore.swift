import Foundation

public struct ModSetupStore: Sendable {
    public let settings: GraftSettings
    public let paths: GraftPaths

    public init(settings: GraftSettings, paths: GraftPaths) {
        self.settings = settings
        self.paths = paths
    }

    public var displayVersion: String? { AppBundle.shortVersion(at: settings.game.gameApp) }

    public var key: String { displayVersion.map(key(forDisplayVersion:)) ?? "default" }

    func key(forDisplayVersion version: String) -> String {
        settings.definition.versionFolder(forDisplayVersion: version)
    }

    public func key(forApp app: String) -> String? {
        AppBundle.shortVersion(at: app).map(key(forDisplayVersion:))
    }

    public var folder: URL { paths.setups.appending(path: settings.definition.mods.kind.rawValue, directoryHint: .isDirectory) }

    public func file(for key: String) -> URL { folder.appending(path: "\(key).json") }

    public func saved(_ key: String) throws -> ModSetup? {
        try JSONFile.read(ModSetup.self, from: file(for: key))
    }

    func allKeys() -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [])
            .filter { $0.hasSuffix(".json") }.map { String($0.dropLast(5)) }.sorted()
    }

    public func save(_ setup: ModSetup, as key: String? = nil) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try JSONFile.write(setup, to: file(for: key ?? self.key))
    }

    public func otherSetups() -> [String: ModSetup] {
        var setups: [String: ModSetup] = [:]
        for other in allKeys() where other != key {
            if let setup = try? saved(other) { setups[other] = setup }
        }
        return setups
    }

    public func otherVersionsByMod() -> [String: [String]] {
        Self.versionsByMod(otherSetups().values)
    }

    public static func versionsByMod(_ setups: some Sequence<ModSetup>) -> [String: [String]] {
        var versions: [String: [String]] = [:]
        for setup in setups.sorted(by: { $0.version.compare($1.version, options: .numeric) == .orderedDescending }) {
            for entry in setup.mods { versions[entry.id, default: []].append(setup.version) }
        }
        return versions
    }

    func modsInOtherVersions() -> Set<String> {
        Set(otherSetups().values.flatMap { $0.mods.map(\.id) })
    }

    public func current(library: [InstalledMod], comingFrom previous: ModSetup? = nil) throws -> ModSetup {
        let version = displayVersion ?? "unknown"
        let stored = try saved(key)
        let base = stored ?? (previous ?? latestOther()).map { ModSetup(game: settings.definition.id, version: version, mods: $0.mods) }
            ?? ModSetup(game: settings.definition.id, version: version, seed: library)
        var setup = base.reconciled(with: library, inOtherVersions: modsInOtherVersions())
        setup.version = version
        if setup != stored { try save(setup) }
        return setup
    }

    func latestOther() -> ModSetup? {
        let candidates = allKeys().filter { $0 != key }.map { (key: $0, date: (try? file(for: $0).resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast) }
        guard let newest = candidates.max(by: { $0.date < $1.date }) else { return nil }
        return try? saved(newest.key)
    }

    public func copyingOrder(of other: ModSetup, into current: ModSetup, library: [InstalledMod]) -> ModSetup {
        ModSetup(game: current.game, version: current.version, mods: other.mods)
            .reconciled(with: library, inOtherVersions: modsInOtherVersions())
    }

    public func recordAdded(_ added: AddedMod) throws {
        guard let mod = added.mods.first(where: { $0.id == added.id }) else { return }
        let current = key
        for key in allKeys() {
            guard var setup = try saved(key) else { continue }
            guard key == current || setup.contains(mod.id) || added.replacedIds.contains(where: setup.contains) else { continue }
            let before = setup
            setup.add(mod, replacing: added.replacedIds)
            if setup != before { try save(setup, as: key) }
        }
    }

    public func copy(_ entry: ModSetup.Entry, from current: ModSetup, toVersion version: String) throws {
        let target = key(forDisplayVersion: version)
        guard target != key else {
            throw GraftError("The game app for \(version) shares this version's load order.")
        }
        let stored = try saved(target)
        var setup = stored ?? ModSetup(game: settings.definition.id, version: version, mods: current.mods)
        if !setup.contains(entry.id) { setup.mods.append(entry) }
        if setup != stored { try save(setup, as: target) }
    }

    public func recordRemoved(_ id: String) throws {
        for key in allKeys() {
            guard var setup = try saved(key), setup.contains(id) else { continue }
            setup.remove(id)
            try save(setup, as: key)
        }
    }
}
