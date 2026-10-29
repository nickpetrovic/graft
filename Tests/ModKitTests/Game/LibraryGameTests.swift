import Foundation
import Testing
@testable import ModKit

struct LibraryGameTests {
    let folder: TemporaryFolder

    init() throws {
        folder = try TemporaryFolder()
    }

    func all(_ settings: GraftSettings?, saved: [String: GameSettings] = [:],
             catalog: GameCatalog = GameCatalog(games: [totk, ot0, botw])) -> [LibraryGame] {
        LibraryGame.all(current: settings, catalog: catalog, savedGame: { saved[$0.id] },
                        detector: { SettingsDetector(game: $0, home: folder.url.appending(path: "home"), applications: folder.url.appending(path: "Applications")) })
    }

    @Test func gamesWithoutAnEngineSayWhyAndAreNotInstalled() throws {
        let entry = try #require(all(GraftSettings(definition: totk, general: GeneralSettings(), game: GameSettings())).first { $0.id == "botw" })
        #expect(!entry.isInstalled)
        #expect(entry.status == "Not supported yet")
    }

    @Test func theCurrentGamesAppAndItsVersionAreListed() throws {
        let app = try folder.app("TotK", identifier: totk.bundleIdentifier, version: "1.2.1")
        let other = try folder.app("TotK 1.4.3", identifier: totk.bundleIdentifier, version: "1.4.3")
        let settings = GraftSettings(definition: totk, general: GeneralSettings(),
                                     game: GameSettings(gameApp: app, otherApps: [GameSettings.OtherApp(gameApp: other, update: "")]))

        let entry = try #require(all(settings).first { $0.id == "totk" })

        #expect(entry.isInstalled)
        #expect(entry.app == app)
        #expect(entry.status == "Version 1.2.1")
    }

    @Test func anotherGameIsFoundFromItsSavedSettingsOrTheUsualFolders() throws {
        let saved = try folder.app("Saved/Octopath Traveler 0", identifier: ot0.bundleIdentifier, version: "1.0.5")
        let found = try folder.app("home/Games/Octopath Traveler 0", identifier: ot0.bundleIdentifier, version: "1.0.4")

        #expect(all(nil, saved: ["ot0": GameSettings(gameApp: saved)]).first { $0.id == "ot0" }?.app == saved)
        #expect(all(nil).first { $0.id == "ot0" }?.app.map { URL(fileURLWithPath: $0).standardizedFileURL.path } == URL(fileURLWithPath: found).standardizedFileURL.path)
        #expect(all(nil).first { $0.id == "totk" }?.app == nil)
    }

    @Test func aSupportedGameWithoutAnAppSaysSo() {
        #expect(LibraryGame(game: ot0, app: nil, version: nil).status == "No game app yet")
        #expect(LibraryGame(game: ot0, app: "/Apps/OT0.app", version: nil).status == "Version unknown")
    }
}
