import Foundation
import Testing
@testable import ModKit

struct JSONFileTests {
    @Test func aMissingJSONFileIsNotAnError() throws {
        let folder = try TemporaryFolder()
        #expect(try JSONFile.read(GameSettings.self, from: folder.url.appending(path: "missing.json")) == nil)
        try JSONFile.write(GameSettings(gameApp: "/Apps/Game.app"), to: folder.url.appending(path: "nested/settings.json"))
        #expect(try JSONFile.read(GameSettings.self, from: folder.url.appending(path: "nested/settings.json"))?.gameApp == "/Apps/Game.app")
    }
}
