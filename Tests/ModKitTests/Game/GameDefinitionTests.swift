import Foundation
import Testing
@testable import ModKit

struct GameDefinitionTests {
    @Test func versionsBecomeFolderNames() {
        #expect(totk.versionFolder(forDisplayVersion: "1.2.1") == "v121")
        #expect(totk.versionFolder(forDisplayVersion: "1.0.0") == "v0")
        #expect(botw.versionFolder(forDisplayVersion: "1.6.0") == "botw160")
        #expect(ot0.versionFolder(forDisplayVersion: "1.0.5") == "v105")
    }

    @Test func missingFieldsFallBackToNamesMadeFromTheId() throws {
        let game = try JSONDecoder().decode(GameDefinition.self, from: Data(#"{"id": "port", "name": "Port", "titleId": "0100000000000000", "app": {"bundleIdentifier": "org.example.port"}}"#.utf8))
        #expect(game.appFileName == "Port.app")
        #expect(game.unsupportedReason == "Graft can't manage Port mods yet.")
        #expect(game.logFileName == "port")
        #expect(game.workFolderName == "port_build")
        #expect(game.workTreeName == "")
        #expect(game.logLinePrefix == "[port]")
        #expect(!game.supportsTitleText)
        #expect(game.files.isEmpty)
        #expect(game.languages(inVersion: "1.0.0").isEmpty)
    }

    @Test func aLanguageLimitedToSomeVersionsIsOnlyOfferedThere() {
        let portuguese = TkSharpSettings.Language(code: "USpt", name: "Portuguese", versions: ["1.4.3"])
        let english = TkSharpSettings.Language(code: "USen", name: "English", versions: nil)
        #expect(portuguese.isAvailable(inVersion: "1.4.3"))
        #expect(!portuguese.isAvailable(inVersion: "1.2.1"))
        #expect(!portuguese.isAvailable(inVersion: nil))
        #expect(english.isAvailable(inVersion: nil))
        #expect(totk.languages(inVersion: "1.2.1").map(\.code).contains("USen"))
        #expect(!totk.languages(inVersion: "1.2.1").map(\.code).contains("USpt"))
    }

    @Test func eachGameHasItsOwnDataFolderAndLog() {
        let totkPaths = GraftPaths.standard(for: totk)
        let botwPaths = GraftPaths.standard(for: botw)
        #expect(totkPaths.root == botwPaths.root)
        #expect(totkPaths.support.lastPathComponent == "totk")
        #expect(botwPaths.support.lastPathComponent == "botw")
        #expect(totkPaths.gameData.path.hasSuffix("MacNativeGames/TOTK"))
        #expect(botwPaths.gameData.path.hasSuffix("MacNativeGames/BotW"))
        #expect(botwPaths.gameLog.lastPathComponent == "botw.log")
        #expect(botwPaths.modsFolder(version: "botw160").path.hasSuffix("MacNativeGames/BotW/mods/botw160"))
        #expect(totkPaths.setups.path.hasSuffix("Graft/games/totk/setups"))
    }
}
