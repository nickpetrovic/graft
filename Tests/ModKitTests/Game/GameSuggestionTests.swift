import Foundation
import Testing
@testable import ModKit

struct GameSuggestionTests {
    let folder: TemporaryFolder

    init() throws {
        folder = try TemporaryFolder()
    }

    @Test func appsWithATemplateAreSuggestedUntilTheirGameIsAdded() throws {
        _ = try folder.app("Games/Tears of the Kingdom", identifier: totk.bundleIdentifier, version: "1.4.3")
        _ = try folder.app("Games/Tears of the Kingdom 1.2.1", identifier: totk.bundleIdentifier, version: "1.2.1")
        _ = try folder.app("Games/Octopath Traveler 0", identifier: ot0.bundleIdentifier, version: "1.0.5")
        _ = try folder.app("Games/Other", identifier: "com.example.other")
        let folders = [folder.url.appending(path: "Games")]

        let none = GameSuggestion.all(templates: bundledTemplates, catalog: GameCatalog(games: []), folders: folders)
        let withOt0 = GameSuggestion.all(templates: bundledTemplates, catalog: GameCatalog(games: [ot0]), folders: folders)

        #expect(none.map(\.template.id) == ["ot0", "totk"])
        #expect(none.first { $0.template.id == "totk" }?.version == "1.4.3")
        #expect(withOt0.map(\.template.id) == ["totk"])
    }
}
