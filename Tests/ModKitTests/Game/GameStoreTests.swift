import Foundation
import Testing
@testable import ModKit

struct GameStoreTests {
    let folder: TemporaryFolder
    let store: GameStore

    init() throws {
        folder = try TemporaryFolder()
        store = GameStore(folder: folder.url.appending(path: "games"))
    }

    @Test func savedGamesAreLoadedBackFromTheirOwnFolders() throws {
        try store.save(totk)
        try store.save(ot0)

        let catalog = store.load()

        #expect(catalog.games == [ot0, totk])
        #expect(catalog.problems.isEmpty)
        #expect(FileManager.default.fileExists(atPath: folder.path("games/totk/game.json")))
    }

    @Test func removingAGameRemovesOnlyItsDefinition() throws {
        try store.save(ot0)
        try folder.write("games/ot0/game-settings.json", "{}")

        try store.remove(id: "ot0")
        try store.remove(id: "missing")

        #expect(store.load().games.isEmpty)
        #expect(FileManager.default.fileExists(atPath: folder.path("games/ot0/game-settings.json")))
    }

    @Test func aFolderWithoutADefinitionIsNotAGame() throws {
        try folder.write("games/botw/game-settings.json", "{}")
        try store.save(ot0)
        #expect(store.load().games.map(\.id) == ["ot0"])
    }

    @Test func anUnreadableDefinitionIsLeftOutAndSaysWhichFieldIsWrong() throws {
        try store.save(ot0)
        try folder.write("games/port/game.json", #"{"id": "port", "name": "Port", "titleId": "0100000000000000", "files": [{"role": "gameApp"}]}"#)

        let catalog = store.load()

        #expect(catalog.games.map(\.id) == ["ot0"])
        #expect(catalog.unreadable.keys.sorted() == ["port"])
        #expect(catalog.problems.first?.hasSuffix("files[0].label is missing.") == true)
        #expect(catalog.problems.first?.hasSuffix("..") == false)
    }

    @Test func aDefinitionInAnotherGamesFolderIsLeftOut() throws {
        try JSONFile.write(ot0, to: folder.url.appending(path: "games/other/game.json"))

        let catalog = store.load()

        #expect(catalog.games.isEmpty)
        #expect(catalog.problems.first?.contains("describes ot0, but it is in the folder for other") == true)
    }

    @Test func anExportLeavesOutTheTemplateItStartedFrom() throws {
        let game = try #require(bundledTemplates.template(id: "ot0")).game()
        let file = folder.url.appending(path: "Octopath Traveler 0.json")

        try GameStore.export(game, to: file)

        let exported = try GameStore.read(from: file)
        #expect(game.template != nil)
        #expect(exported.template == nil)
        #expect(exported.name == game.name)
    }
}
