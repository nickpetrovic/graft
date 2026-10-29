import Foundation
import Testing
@testable import ModKit

struct GameEnvironmentTests {
    @Test func onlyAProgramInsideTheGameAppCountsAsTheGameRunning() throws {
        let running = try #require(Bundle.main.executableURL).deletingLastPathComponent().path
        func settings(gameApp: String) -> GraftSettings {
            GraftSettings(definition: totk, general: GeneralSettings(), game: GameSettings(gameApp: gameApp))
        }
        #expect(GameEnvironment.isGameRunning(settings(gameApp: running)))
        #expect(!GameEnvironment.isGameRunning(settings(gameApp: running + "-other")))
        #expect(!GameEnvironment.isGameRunning(settings(gameApp: "")))
    }

    @Test func aGameWithoutAPatchSiteScriptHasNoReservedSites() async throws {
        let settings = GraftSettings(definition: ot0, general: GeneralSettings(), game: GameSettings())
        #expect(try await GameEnvironment.reservedSites(settings: settings, layout: layout121).isEmpty)
    }
}
