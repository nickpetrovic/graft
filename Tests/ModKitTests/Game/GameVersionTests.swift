import Foundation
import Testing
@testable import ModKit

struct GameVersionTests {
    @Test func theVersionButtonListsEveryAppOfTheGameByVersion() throws {
        let folder = try TemporaryFolder()
        let older = try folder.app("TotK", identifier: totk.bundleIdentifier, version: "1.2.1")
        let newer = try folder.app("TotK 1.4.3", identifier: totk.bundleIdentifier, version: "1.4.3")
        let copy = try folder.app("TotK copy", identifier: totk.bundleIdentifier, version: "1.4.3")
        let other = try folder.app("BotW", identifier: botw.bundleIdentifier, version: "1.6.0")
        func settings(_ others: [String]) -> GraftSettings {
            GraftSettings(definition: totk, general: GeneralSettings(),
                          game: GameSettings(gameApp: older, otherApps: others.map { GameSettings.OtherApp(gameApp: $0, update: "") }))
        }

        let versions = GameVersion.all(for: settings([newer, other, "/Missing.app"]))

        #expect(versions.map(\.title) == ["1.4.3", "1.2.1"])
        #expect(versions.map(\.app) == [newer, older])
        #expect(GameVersion.all(for: settings([])).map(\.title) == ["1.2.1"])
        #expect(GameVersion.all(for: settings([]), found: [older, newer, other]).map(\.app) == [newer, older])
        #expect(Set(GameVersion.all(for: settings([newer]), found: [copy]).map(\.title)) == ["1.4.3 (TotK 1.4.3)", "1.4.3 (TotK copy)", "1.2.1"])
    }

    @Test func versionsSortByNumberNotByText() throws {
        let folder = try TemporaryFolder()
        let nine = try folder.app("Nine", identifier: totk.bundleIdentifier, version: "1.9.0")
        let ten = try folder.app("Ten", identifier: totk.bundleIdentifier, version: "1.10.0")
        let settings = GraftSettings(definition: totk, general: GeneralSettings(), game: GameSettings(gameApp: nine))
        #expect(GameVersion.all(for: settings, found: [ten]).map(\.title) == ["1.10.0", "1.9.0"])
    }

    @Test func noGameAppMeansNoVersions() {
        #expect(GameVersion.all(for: GraftSettings(definition: totk, general: GeneralSettings(), game: GameSettings(gameApp: "/Missing.app"))).isEmpty)
        #expect(GameVersion.name(of: "/Apps/TotK 1.4.3.app") == "TotK 1.4.3")
    }
}
