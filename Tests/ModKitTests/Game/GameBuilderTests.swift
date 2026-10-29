import Foundation
import Testing
@testable import ModKit

struct GameBuilderTests {
    @Test func buildLinesBecomeStatusMessages() {
        #expect(GameBuilder.status(forLine: "[12:00:01] 2/5 extract: reading the update") == "Rebuilding the game app (step 2 of 5): reading the update")
        #expect(GameBuilder.status(forLine: "  signing ") == "Rebuilding the game app: signing")
    }

    @Test func aGameWithoutABuildScriptCannotBeRebuilt() async throws {
        let builder = GameBuilder(settings: GraftSettings(definition: ot0, general: GeneralSettings(), game: GameSettings()))
        let error = try await #require(throws: GraftError.self) { try await builder.build(modFolder: nil) { _ in } }
        #expect(error.message.contains("Octopath Traveler 0"))
    }
}
