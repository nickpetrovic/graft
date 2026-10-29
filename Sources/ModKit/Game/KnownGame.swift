import Foundation

public struct KnownGame: Sendable, Hashable {
    public let name: String
    public let signatures: GameDefinition.ModSignatures

    public static func others(than game: GameDefinition, catalog: GameCatalog, templates: GameTemplates) -> [KnownGame] {
        var seen: Set<String> = [game.id]
        if let identifier = game.bundleIdentifier { seen.insert(identifier) }
        let definitions = catalog.games + templates.templates.map(\.definition)
        return definitions.compactMap { other in
            guard seen.insert(other.id).inserted, other.bundleIdentifier.map({ seen.insert($0).inserted }) ?? true,
                  let signatures = other.modSignatures, !signatures.isEmpty else { return nil }
            return KnownGame(name: other.name, signatures: signatures)
        }
    }
}

extension KnownGame {
    public static func owner(of paths: [String], addedTo game: GameDefinition, among others: [KnownGame]) -> KnownGame? {
        let paths = paths.map { String($0.replacingOccurrences(of: "\\", with: "/").trimmingPrefix("/")) }
        guard !paths.isEmpty, !paths.contains(where: { game.modSignatures?.matches($0) == true }) else { return nil }
        let threshold = max(1, (paths.count + 1) / 2)
        return others.first { other in paths.filter(other.signatures.matches).count >= threshold }
    }
}
