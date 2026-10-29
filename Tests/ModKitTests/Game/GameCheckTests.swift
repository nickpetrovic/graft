import Foundation
import Testing
@testable import ModKit

struct GameCheckTests {
    func settings(_ folder: TemporaryFolder) -> GraftSettings {
        GraftSettings(definition: totk, general: GeneralSettings(macNativeGames: folder.url.appending(path: "mng").path),
                      game: GameSettings(gameApp: folder.url.appending(path: "Missing.app").path))
    }

    @Test func missingScriptsBlockPlay() throws {
        let folder = try TemporaryFolder()
        try folder.write("mng/build_app.py")
        try folder.write("mng/games/totk/scripts/make_mod_manifest.py")

        let problems = GameCheck.blockingProblems(for: settings(folder))

        #expect(problems == ["Your MacNativeGames folder doesn't have games/totk/scripts/patch_sites.py, which Graft uses to check code mods for Tears of the Kingdom."])
    }

    @Test func nothingIsCheckedWithoutAMacNativeGamesFolderOrForUnsupportedGames() throws {
        let folder = try TemporaryFolder()
        #expect(GameCheck.blockingProblems(for: settings(folder)).isEmpty)
        try folder.write("mng/build_app.py")
        #expect(GameCheck.blockingProblems(for: GraftSettings(definition: botw, general: settings(folder).general, game: GameSettings())).isEmpty)
    }

    @Test func aDefinitionIsCheckedAgainstTheMacNativeGamesFolder() throws {
        let folder = try TemporaryFolder()
        try folder.write("mng/build_app.py")
        var game = ot0
        game.macNativeGamesFolder = "other"

        let problems = GameCheck.problems(in: game, macNativeGames: folder.url.appending(path: "mng"))

        #expect(problems == [
            "Your MacNativeGames folder doesn't have games/other.",
            "Your MacNativeGames folder doesn't have games/ot0/scripts/make_mod_manifest.py, which Graft uses to install data mods for Octopath Traveler 0.",
        ])
        #expect(GameCheck.problems(in: game, macNativeGames: nil).isEmpty)
    }

    @Test func aMissingAppIdentifierIsReportedOnce() throws {
        let folder = try TemporaryFolder()
        try folder.write("mng/build_app.py")
        try folder.write("mng/games/ot0/scripts/make_mod_manifest.py")
        var game = ot0
        game.app = nil

        let problems = GameDraft.editing(game).problems(in: GameCatalog(games: [ot0]), macNativeGames: folder.url.appending(path: "mng"))

        #expect(problems == ["Enter the app identifier, so Graft can find and start the game."])
    }

    static let macNativeGames: URL? = ProcessInfo.processInfo.environment["GRAFT_MACNATIVEGAMES"].map { URL(fileURLWithPath: $0) }

    @Test(.enabled(if: macNativeGames != nil, "set GRAFT_MACNATIVEGAMES to a MacNativeGames checkout to run this test"))
    func theTemplatesMatchTheMacNativeGamesCheckout() throws {
        let root = try #require(Self.macNativeGames)
        let problems = bundledTemplates.templates.flatMap { template in
            GameCheck.problems(in: template.definition, macNativeGames: root).map { "\(template.id): \($0)" }
        }
        #expect(problems.isEmpty, "\(problems)")
    }

    @Test(.enabled(if: macNativeGames != nil, "set GRAFT_MACNATIVEGAMES to a MacNativeGames checkout to run this test"))
    func theMessagesGraftReadsStillExistInMacNativeGames() throws {
        let root = try #require(Self.macNativeGames)
        var files = [root.appending(path: "build_app.py")]
        if let enumerator = FileManager.default.enumerator(at: root.appending(path: "games"), includingPropertiesForKeys: nil) {
            for case let file as URL in enumerator where ["py", "c", "m"].contains(file.pathExtension)
                && (file.path.contains("/scripts/") || file.path.contains("/runtime/")) {
                files.append(file)
            }
        }
        let sources = try files.map { try String(contentsOf: $0, encoding: .utf8) }.joined(separator: "\n")
        let launchVariables = bundledTemplates.templates.compactMap(\.definition.tkSharp?.codeMods?.launchVariable)
        for message in MacNativeGames.messages + launchVariables {
            #expect(sources.contains(message), "MacNativeGames no longer prints '\(message)'")
        }
    }
}

struct GameCheckUnreadableTests {
    @Test func anUnreadableDefinitionBlocksPlay() {
        let settings = GraftSettings(definition: ot0, general: GeneralSettings(), game: GameSettings())
        let problems = GameCheck.blockingProblems(for: settings, catalog: GameCatalog(games: [], unreadable: ["ot0": "game.json couldn't be read: bad."]))
        #expect(problems == ["game.json couldn't be read: bad. Graft is using what it read before. Fix the file, or edit the game to save it again."])
    }
}
