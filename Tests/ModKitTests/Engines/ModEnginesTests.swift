import Foundation
import Testing
@testable import ModKit

struct ModEnginesTests {
    @Test func eachSupportedGameNamesTheModsItTakes() {
        #expect(totk.mods.kind.modFormats?.contains("tkcl") == true)
        #expect(ot0.mods.kind.modFormats?.contains(".pak") == true)
        #expect(botw.mods.kind.modFormats == nil)
    }

    @Test func aGameWithoutAnEngineExplainsWhy() throws {
        let error = try #require(throws: GraftError.self) {
            try ModEngines.make(settings: GraftSettings(definition: botw, general: GeneralSettings(), game: GameSettings()), paths: GraftPaths.standard(for: botw))
        }
        #expect(error.message == botw.unsupportedReason)
        #expect(botw.unsupportedReason?.contains("Breath of the Wild") == true)
        #expect(totk.unsupportedReason == nil)
    }

    @Test func aFilesGameGetsTheFilesEngineWithItsSettings() throws {
        let engine = try ModEngines.make(settings: GraftSettings(definition: ot0, general: GeneralSettings(), game: GameSettings()), paths: GraftPaths.standard(for: ot0))
        let files = try #require(engine as? FileModEngine)
        #expect(files.fileMods == ot0.fileMods)
    }
}
