import Foundation
import Testing
@testable import ModKit

struct ModSupportTests {
    func roundTrip(_ game: GameDefinition) throws -> GameDefinition {
        try JSONDecoder().decode(GameDefinition.self, from: JSONFile.encode(game))
    }

    @Test func everyKindOfModSupportIsWrittenAndReadBack() throws {
        var unsupported = botw
        unsupported.mods = .unsupported(reason: nil)
        for game in [totk, ot0, botw, unsupported] {
            #expect(try roundTrip(game) == game)
        }
    }

    @Test func theEngineIsNamedInsideTheModsSettings() throws {
        let json = try #require(JSONSerialization.jsonObject(with: JSONFile.encode(ot0)) as? [String: Any])
        let mods = try #require(json["mods"] as? [String: Any])
        #expect(mods["engine"] as? String == "files")
        #expect(mods["pakFolder"] as? String == "Octopath_Traveler0/Content/Paks/~mods")
    }

    @Test func anUnknownEngineIsRejected() {
        let json = #"{"id": "port", "name": "Port", "titleId": "0100000000000000", "mods": {"engine": "magic"}}"#
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(GameDefinition.self, from: Data(json.utf8)) }
    }

    @Test func eachKindNamesTheScriptsItNeeds() {
        #expect(totk.mods.engineSettings?.scripts.map(\.path) == ["build_app.py", "games/totk/scripts/make_mod_manifest.py", "games/totk/scripts/patch_sites.py"])
        #expect(ot0.mods.engineSettings?.scripts.map(\.path) == ["games/ot0/scripts/make_mod_manifest.py"])
        #expect(botw.mods.engineSettings == nil)
        #expect(ModSupport.Kind.allCases.map { ModSupport.empty($0).kind } == ModSupport.Kind.allCases)
    }

    @Test func emptySettingsSayWhatIsMissing() {
        #expect(TkSharpSettings().problems().count == 2)
        #expect(FileModSettings().problems().count == 2)
        let languages = TkSharpSettings(buildScript: "b", manifestScript: "m", codeMods: TkSharpSettings.CodeMods(),
                                        languages: [TkSharpSettings.Language(code: "USen", name: "English"), TkSharpSettings.Language(code: "USen", name: "")])
        #expect(languages.problems() == [
            "Enter the variable that passes code mods to the game, or turn code mods off.",
            "Every text language needs a code and a name.",
            "Two text languages have the same code.",
        ])
    }
}
