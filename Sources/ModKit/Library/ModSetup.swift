import Foundation

public struct ModSetup: Codable, Sendable, Equatable {
    public struct Entry: Codable, Sendable, Equatable {
        public var id: String
        public var name: String
        public var enabled: Bool
        public var options: [String: [String]]

        public init(id: String, name: String, enabled: Bool, options: [String: [String]] = [:]) {
            self.id = id
            self.name = name
            self.enabled = enabled
            self.options = options
        }
    }

    public var game: String
    public var version: String
    public var mods: [Entry]

    public init(game: String, version: String, mods: [Entry]) {
        self.game = game
        self.version = version
        self.mods = mods
    }

    public init(game: String, version: String, seed library: [InstalledMod]) {
        self.init(game: game, version: version, mods: library.sorted { $0.position < $1.position }.map(Self.entry(seededFrom:)))
    }

    static func entry(seededFrom mod: InstalledMod) -> Entry {
        Entry(id: mod.id, name: mod.name, enabled: mod.enabled, options: mod.selectedOptions)
    }

    public func reconciled(with library: [InstalledMod], inOtherVersions: Set<String> = []) -> ModSetup {
        let known = Dictionary(library.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var entries = mods.filter { known[$0.id] != nil }
        let listed = Set(entries.map(\.id))
        for mod in library.sorted(by: { $0.position < $1.position }) where !listed.contains(mod.id) && !inOtherVersions.contains(mod.id) {
            entries.insert(Self.entry(seededFrom: mod), at: min(mod.position, entries.count))
        }
        entries = entries.map { entry in
            guard let mod = known[entry.id] else { return entry }
            var entry = entry
            entry.name = mod.name
            entry.options = Self.validOptions(entry.options, for: mod)
            return entry
        }
        return ModSetup(game: game, version: version, mods: entries)
    }

    static func validOptions(_ chosen: [String: [String]], for mod: InstalledMod) -> [String: [String]] {
        var result: [String: [String]] = [:]
        for group in mod.optionGroups {
            let names = Set(group.options.map(\.name))
            var picked = (chosen[group.name] ?? group.options.filter(\.selected).map(\.name)).filter(names.contains)
            if !group.allowsMultiple, picked.count > 1 { picked = [picked[0]] }
            if group.isRequired, picked.isEmpty, let first = group.options.first { picked = [first.name] }
            if !picked.isEmpty || chosen[group.name] != nil { result[group.name] = picked }
        }
        return result
    }

    public func applied(to library: [InstalledMod]) -> [InstalledMod] {
        let known = Dictionary(library.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return mods.enumerated().compactMap { position, entry in
            known[entry.id].map { $0.configured(position: position, enabled: entry.enabled, options: entry.options) }
        }
    }

    public mutating func setEnabled(_ id: String, _ enabled: Bool) {
        guard let index = mods.firstIndex(where: { $0.id == id }) else { return }
        mods[index].enabled = enabled
    }

    public mutating func move(_ id: String, to position: Int) {
        guard let index = mods.firstIndex(where: { $0.id == id }) else { return }
        let entry = mods.remove(at: index)
        mods.insert(entry, at: min(max(position, 0), mods.count))
    }

    public mutating func select(_ option: ModOption, in group: ModOptionGroup, of id: String, selected: Bool) throws {
        guard let index = mods.firstIndex(where: { $0.id == id }) else { return }
        var picked = mods[index].options[group.name] ?? []
        if selected {
            picked = group.allowsMultiple ? picked.filter { $0 != option.name } + [option.name] : [option.name]
        } else {
            guard !(group.isRequired && picked == [option.name]) else {
                throw GraftError("The group \"\(group.name)\" needs at least one option.")
            }
            picked.removeAll { $0 == option.name }
        }
        mods[index].options[group.name] = picked
    }

    public mutating func add(_ mod: InstalledMod, replacing replaced: [String]) {
        if let index = mods.firstIndex(where: { replaced.contains($0.id) }) {
            var entry = Self.entry(seededFrom: mod)
            entry.enabled = mods[index].enabled
            entry.options = Self.validOptions(mods[index].options, for: mod)
            mods[index] = entry
            mods.removeAll { replaced.contains($0.id) && $0.id != mod.id }
        } else if let index = mods.firstIndex(where: { $0.id == mod.id }) {
            mods[index].name = mod.name
            mods[index].options = Self.validOptions(mods[index].options, for: mod)
        } else {
            mods.append(Self.entry(seededFrom: mod))
        }
    }

    public mutating func remove(_ id: String) {
        mods.removeAll { $0.id == id }
    }

    public func contains(_ id: String) -> Bool {
        mods.contains { $0.id == id }
    }

    public func entry(_ id: String) -> Entry? {
        mods.first { $0.id == id }
    }

    public func importing(_ other: ModSetup, library: [InstalledMod]) -> (setup: ModSetup, missing: [String]) {
        var remaining = library
        var entries: [Entry] = []
        var missing: [String] = []
        for entry in other.mods {
            let index = remaining.firstIndex { $0.id == entry.id }
                ?? remaining.firstIndex { $0.name.caseInsensitiveCompare(entry.name) == .orderedSame }
            guard let index else {
                missing.append(entry.name.isEmpty ? entry.id : entry.name)
                continue
            }
            let mod = remaining.remove(at: index)
            entries.append(Entry(id: mod.id, name: mod.name, enabled: entry.enabled, options: Self.validOptions(entry.options, for: mod)))
        }
        for mod in remaining.sorted(by: { $0.position < $1.position }) {
            var entry = Self.entry(seededFrom: mod)
            entry.enabled = false
            entries.append(entry)
        }
        return (ModSetup(game: game, version: version, mods: entries), missing)
    }

    public static func read(from url: URL) throws -> ModSetup {
        guard let setup = try JSONFile.read(ModSetup.self, from: url) else {
            throw GraftError("\(url.path) does not exist.")
        }
        return setup
    }
}

extension InstalledMod {
    func configured(position: Int, enabled: Bool, options: [String: [String]]) -> InstalledMod {
        InstalledMod(id: id, name: name, version: version, author: author, description: description, enabled: enabled, position: position,
                     dataFiles: dataFiles, textFiles: textFiles, subSdkFiles: subSdkFiles, cheatFiles: cheatFiles, codePatchBuilds: codePatchBuilds,
                     optionGroups: optionGroups.map { group in
                         let picked = Set(options[group.name] ?? [])
                         return ModOptionGroup(name: group.name, description: group.description, type: group.type,
                                               options: group.options.map { ModOption(id: $0.id, name: $0.name, description: $0.description, selected: picked.contains($0.name)) })
                     })
    }
}
