import Foundation
import Testing
@testable import ModKit

struct SetupCheckTests {
    let folder: TemporaryFolder

    init() throws {
        folder = try TemporaryFolder()
    }

    @Test func missingSharedSettingsAreNamed() throws {
        let empty = SetupCheck(GraftSettings(definition: totk, general: GeneralSettings(), game: GameSettings()))
        #expect(empty.general == ["Choose your MacNativeGames folder.", "Choose the folder with your keys."])

        let wrong = SetupCheck(GraftSettings(definition: totk, general: GeneralSettings(macNativeGames: folder.path("mng"), keysFolder: folder.path("keys")),
                                             game: GameSettings()))
        #expect(wrong.general == ["The folder \(folder.path("mng")) has no build_app.py, so it isn't a MacNativeGames folder.",
                                  "The folder \(folder.path("keys")) has no prod.keys."])
    }

    @Test func eachMissingFileHasItsOwnProblem() throws {
        let check = SetupCheck(GraftSettings(definition: totk, general: GeneralSettings(), game: GameSettings()))
        #expect(check.files.map(\.file.role) == [.gameApp, .baseGame, .update, .workFolder])
        #expect(check.problem(for: .gameApp) == "Choose the game app.")
        #expect(check.problem(for: .update) == "Choose the update.")
        #expect(check.problems == check.general + check.gameProblems)
    }

    @Test func anUpdateForAnotherVersionIsRefused() throws {
        let gameApp = try folder.app("TotK", identifier: totk.bundleIdentifier, version: "1.2.1")
        let update = try folder.write("update.nsp").path
        let settings = GraftSettings(definition: totk, general: GeneralSettings(), game: GameSettings(gameApp: gameApp, update: update))

        #expect(SetupCheck(settings, updateVersion: "1.4.3").problem(for: .update) == "This update is 1.4.3, but the game app is 1.2.1. Choose the 1.2.1 update.")
        #expect(SetupCheck(settings, updateVersion: "1.2.1").problem(for: .update) == nil)
        var unset = settings
        unset.game.update = ""
        #expect(SetupCheck(unset).problem(for: .update) == "Choose the 1.2.1 update.")
    }

    @Test func anAppOfAnotherGameIsRefused() throws {
        let gameApp = try folder.app("BotW", identifier: botw.bundleIdentifier, version: "1.6.0")
        let check = SetupCheck(GraftSettings(definition: totk, general: GeneralSettings(), game: GameSettings(gameApp: gameApp)))
        #expect(check.problem(for: .gameApp) == "This game app is for Breath of the Wild, not Tears of the Kingdom.")
        let other = try folder.app("Other", identifier: "com.example.other")
        #expect(SetupCheck(GraftSettings(definition: totk, general: GeneralSettings(), game: GameSettings(gameApp: other))).problem(for: .gameApp)
            == "This app's identifier is com.example.other, but Tears of the Kingdom expects org.macnativegames.totk. Choose the right game app, or edit the game.")
    }

    @Test func theWorkFolderNeedsTheBuildsFilesAndPython() throws {
        let work = folder.url.appending(path: "work")
        var settings = GraftSettings(definition: totk, general: GeneralSettings(), game: GameSettings(workFolder: work.path))
        #expect(SetupCheck(settings).problem(for: .workFolder) == "This folder isn't a work folder MacNativeGames built the game in.")

        try folder.write("work/totk/extracted/v121/exefs/main")
        #expect(SetupCheck(settings).problem(for: .workFolder)?.hasPrefix("The work folder has no Python environment yet.") == true)

        try folder.write("work/totk/.venv/bin/python", executable: true)
        #expect(SetupCheck(settings).problem(for: .workFolder) == nil)
        settings.game.workFolder = ""
        #expect(SetupCheck(settings).problem(for: .workFolder) == "Choose the work folder.")
    }

    @Test func aPythonGivenAsAFullPathThatIsMissingIsNamed() throws {
        try folder.write("work/extracted/v105/romfs/a.bin")
        var game = ot0
        game.mods = .files(FileModSettings(manifestScript: "m.py", python: "/missing/bin/python"))
        let settings = GraftSettings(definition: game, general: GeneralSettings(), game: GameSettings(workFolder: folder.path("work")))
        #expect(SetupCheck(settings).problem(for: .workFolder) == "Graft can't run the Python at /missing/bin/python. Check the Python in Edit Game.")
    }

    @Test func unsupportedGamesHaveNoFileProblems() {
        #expect(SetupCheck(GraftSettings(definition: botw, general: GeneralSettings(), game: GameSettings())).files.isEmpty)
    }
}
