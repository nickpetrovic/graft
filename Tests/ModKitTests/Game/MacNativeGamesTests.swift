import Foundation
import Testing
@testable import ModKit

struct MacNativeGamesTests {
    @Test func theFolderCountsOnlyWhenItHasTheBuildScript() throws {
        let folder = try TemporaryFolder()
        let settings = GraftSettings(definition: totk, general: GeneralSettings(macNativeGames: folder.path("mng")), game: GameSettings())
        #expect(MacNativeGames(settings).presentFolder == nil)
        try folder.write("mng/build_app.py")
        #expect(MacNativeGames(settings).presentFolder?.path == folder.path("mng"))
        #expect(MacNativeGames(GraftSettings(definition: totk, general: GeneralSettings(), game: GameSettings())).folder == nil)
    }

    @Test func eachGameUsesThePythonItsBuildMade() {
        let tksharp = GraftSettings(definition: totk, general: GeneralSettings(), game: GameSettings(workFolder: "/work/totk"))
        let files = GraftSettings(definition: ot0, general: GeneralSettings(), game: GameSettings(workFolder: "/work/ot0"))
        #expect(MacNativeGames(tksharp).python.path == "/work/totk/totk/.venv/bin/python")
        #expect(MacNativeGames(files).python.path == "/work/ot0/venv/bin/python")
    }

    @Test func aPythonGivenAsAFullPathIsUsedAsItIs() {
        var game = ot0
        game.mods = .files(FileModSettings(manifestScript: "m.py", python: "/opt/xc3/bin/python"))
        #expect(MacNativeGames(GraftSettings(definition: game, general: GeneralSettings(), game: GameSettings(workFolder: "/work"))).python.path == "/opt/xc3/bin/python")
        game.mods = .files(FileModSettings(manifestScript: "m.py", python: "~/venvs/xc3/bin/python"))
        #expect(MacNativeGames(GraftSettings(definition: game, general: GeneralSettings(), game: GameSettings(workFolder: "/work"))).python.path
            == FileManager.default.homeDirectoryForCurrentUser.appending(path: "venvs/xc3/bin/python").path)
    }

    @Test func runningAScriptNeedsTheFolder() async throws {
        let settings = GraftSettings(definition: totk, general: GeneralSettings(), game: GameSettings())
        let error = try await #require(throws: GraftError.self) { try await MacNativeGames(settings).run("build_app.py", arguments: []) }
        #expect(error.message == "Choose your MacNativeGames folder in Settings first.")
    }
}
