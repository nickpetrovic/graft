import Foundation
import Testing
@testable import ModKit

struct GameLanguageTests {
    @Test func gameLanguageFollowsTheMacLanguage() {
        #expect(GameLanguage.preferred(["en-US"], game: totk, gameVersion: "1.2.1") == "USen")
        #expect(GameLanguage.preferred(["en-GB"], game: totk, gameVersion: "1.2.1") == "USen")
        #expect(GameLanguage.preferred(["ja-JP"], game: totk, gameVersion: "1.2.1") == "JPja")
        #expect(GameLanguage.preferred(["fr-CA"], game: totk, gameVersion: "1.2.1") == "EUfr")
        #expect(GameLanguage.preferred(["es-MX"], game: totk, gameVersion: "1.2.1") == "EUes")
        #expect(GameLanguage.preferred(["zh-Hant-TW"], game: totk, gameVersion: "1.2.1") == "TWzh")
        #expect(GameLanguage.preferred(["zh-Hans-CN"], game: totk, gameVersion: "1.2.1") == "CNzh")
        #expect(GameLanguage.preferred(["zh-HK"], game: totk, gameVersion: "1.2.1") == "TWzh")
        #expect(GameLanguage.preferred(["pt-BR"], game: totk, gameVersion: "1.2.1") == "USen")
        #expect(GameLanguage.preferred(["pt-BR"], game: totk, gameVersion: "1.4.3") == "USpt")
        #expect(GameLanguage.resolve("EUde", for: GraftSettings(definition: totk, general: GeneralSettings(), game: GameSettings())) == "EUde")
    }

    @Test func aLanguageTheGameDoesNotHaveFallsBackToEnglish() {
        #expect(GameLanguage.preferred(["fi-FI"], game: totk, gameVersion: "1.2.1") == "USen")
        #expect(GameLanguage.preferred([], game: totk, gameVersion: "1.2.1") == "USen")
        #expect(GameLanguage.preferred(["ja-JP"], game: ot0, gameVersion: "1.0.5") == "USen")
    }
}
