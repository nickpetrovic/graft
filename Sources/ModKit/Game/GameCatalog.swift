import Foundation

public struct GameCatalog: Sendable, Equatable {
    public let games: [GameDefinition]
    public let unreadable: [String: String]

    public init(games: [GameDefinition], unreadable: [String: String] = [:]) {
        self.games = games.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        self.unreadable = unreadable
    }

    private static let cache = StampedCache<GameCatalog>()

    public static var shared: GameCatalog {
        let store = GameStore.standard
        return cache.value(for: store.definitionFiles()) { store.load() }
    }

    public var problems: [String] { unreadable.sorted { $0.key < $1.key }.map(\.value) }

    public func game(id: String) -> GameDefinition? {
        games.first { $0.id == id }
    }

    public func game(bundleIdentifier: String) -> GameDefinition? {
        games.first { $0.bundleIdentifier == bundleIdentifier }
    }

    public func selection(keeping id: String?) -> CatalogSelection {
        if let id, let game = game(id: id) { return .game(game) }
        if let id, let problem = unreadable[id] { return .unreadable(id: id, problem: problem) }
        return games.first.map(CatalogSelection.game) ?? .none
    }
}

public enum CatalogSelection: Sendable, Equatable {
    case game(GameDefinition)
    case unreadable(id: String, problem: String)
    case none
}
