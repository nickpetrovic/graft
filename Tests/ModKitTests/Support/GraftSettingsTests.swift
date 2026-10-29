import Foundation
import Testing
@testable import ModKit

struct GraftSettingsTests {
    @Test func choosingAnotherAppRemembersThePreviousOneWithItsUpdate() {
        let first = GameSettings(gameApp: "/Apps/TotK 1.2.1.app", update: "/v393216.nsp")
        var second = first
        second.gameApp = "/Apps/TotK 1.4.3.app"
        second.update = "/v720896.nsp"
        second.remember(first)
        #expect(second.otherApps == [GameSettings.OtherApp(gameApp: "/Apps/TotK 1.2.1.app", update: "/v393216.nsp")])

        var back = second
        back.gameApp = "/Apps/TotK 1.2.1.app"
        back.remember(second)
        #expect(back.update == "/v393216.nsp")
        #expect(back.otherApps == [GameSettings.OtherApp(gameApp: "/Apps/TotK 1.4.3.app", update: "/v720896.nsp")])

        var unchanged = back
        unchanged.titleText = "Modded"
        unchanged.remember(back)
        #expect(unchanged.otherApps == back.otherApps)
    }

    @Test func eachFileRoleReadsAndWritesItsOwnPath() {
        var files = GameSettings()
        for role in GameDefinition.FileSetting.Role.allCases {
            files[role] = "/\(role.rawValue)"
        }
        #expect(files == GameSettings(gameApp: "/gameApp", workFolder: "/workFolder", baseGame: "/baseGame", update: "/update"))
        #expect(GameDefinition.FileSetting.Role.allCases.map { files[$0] } == ["/gameApp", "/baseGame", "/update", "/workFolder"])
    }

    @Test func missingFieldsGetTheirDefaults() throws {
        let general = try JSONDecoder().decode(GeneralSettings.self, from: Data("{}".utf8))
        let game = try JSONDecoder().decode(GameSettings.self, from: Data("{}".utf8))
        #expect(general == GeneralSettings())
        #expect(general.keepGameLog)
        #expect(game == GameSettings())
        #expect(game.language == "auto")
        #expect(game.titleText == "Mods Enabled")
    }
}
