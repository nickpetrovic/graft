import Foundation
import Testing
@testable import ModKit

struct UpdateMatchTests {
    @Test func theUpdateIsChosenByTheVersionInsideIt() async throws {
        let folder = try TemporaryFolder()
        let gameApp = try folder.app("home/Games/macOS/Tears of the Kingdom", identifier: totk.bundleIdentifier, version: "1.2.1")
        let newest = try folder.write("home/Games/Switch/TotK [0100F2C0115B6800][v720896].nsp").path
        let matching = try folder.write("home/Games/Switch/renamed.nsp").path
        let otherGame = try folder.write("home/Games/Switch/other.nsp").path
        let settings = GraftSettings(definition: totk, general: GeneralSettings(), game: GameSettings(gameApp: gameApp, update: newest))
        let engine = FakeEngine(mods: [], buildId: "", updates: [
            UpdateFile(path: newest, titleId: totk.titleId, displayVersion: "1.4.3"),
            UpdateFile(path: matching, titleId: totk.titleId.lowercased(), displayVersion: "1.2.1"),
            UpdateFile(path: otherGame, titleId: botw.titleId, displayVersion: "1.2.1"),
        ])
        let detector = SettingsDetector(game: totk, home: folder.url.appending(path: "home"), applications: folder.url.appending(path: "Applications"))

        #expect(try await UpdateMatch.version(of: newest, settings: settings, engine: engine) == "1.4.3")
        #expect(try await UpdateMatch.version(of: otherGame, settings: settings, engine: engine) == nil)
        #expect(try await UpdateMatch.version(of: "", settings: settings, engine: engine) == nil)
        #expect(try await UpdateMatch.find(for: settings, engine: engine, detector: detector) == matching)
    }

    @Test func noMatchIsFoundWithoutAGameAppVersion() async throws {
        let settings = GraftSettings(definition: totk, general: GeneralSettings(), game: GameSettings(gameApp: "/Missing.app"))
        #expect(try await UpdateMatch.find(for: settings, engine: FakeEngine(mods: [], buildId: "")) == nil)
    }
}
