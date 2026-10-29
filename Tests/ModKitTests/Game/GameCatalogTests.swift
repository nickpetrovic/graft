import Foundation
import Testing
@testable import ModKit

struct GameCatalogTests {
    @Test func gamesAreSortedByNameAndFoundByIdOrAppIdentifier() {
        let catalog = GameCatalog(games: [totk, botw, ot0])

        #expect(catalog.games.map(\.id) == ["botw", "ot0", "totk"])
        #expect(catalog.game(id: "ot0") == ot0)
        #expect(catalog.game(bundleIdentifier: "org.macnativegames.totk") == totk)
        #expect(catalog.game(id: "missing") == nil)
    }
}

struct CatalogSelectionTests {
    let catalog = GameCatalog(games: [totk, ot0], unreadable: ["botw": "broken"])

    @Test func theSelectedGameIsKeptWhenItCanBeRead() {
        #expect(catalog.selection(keeping: "totk") == .game(totk))
    }

    @Test func anUnreadableSelectedGameIsReportedInsteadOfSwitchingGames() {
        #expect(catalog.selection(keeping: "botw") == .unreadable(id: "botw", problem: "broken"))
    }

    @Test func aMissingOrNoSelectionFallsBackToTheFirstGame() {
        #expect(catalog.selection(keeping: "gone") == .game(ot0))
        #expect(catalog.selection(keeping: nil) == .game(ot0))
        #expect(GameCatalog(games: []).selection(keeping: "totk") == .none)
        #expect(catalog.problems == ["broken"])
    }
}
