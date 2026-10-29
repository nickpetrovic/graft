import Foundation
import Testing
@testable import ModKit

struct SettingsStoreTests {
    let folder: TemporaryFolder

    init() throws {
        folder = try TemporaryFolder()
    }

    var detector: SettingsDetector {
        SettingsDetector(game: totk, home: folder.url.appending(path: "home"), applications: folder.url.appending(path: "Applications"))
    }

    @Test func detectedSettingsAreSavedOnce() async throws {
        try folder.write("home/.switch/prod.keys")
        let store = SettingsStore(paths: folder.paths, game: totk)

        let settings = try await store.loadSavingDetected(detector: detector)

        #expect(try store.savedGeneral() == settings.general)
        #expect(try store.savedGame() == settings.game)
    }

    @Test func detectedSettingsAreUsedUntilSettingsAreSaved() async throws {
        try folder.write("home/.switch/prod.keys")
        let store = SettingsStore(paths: folder.paths, game: totk)

        var settings = try await store.load(detector: detector)
        #expect(settings.general.keysFolder.hasSuffix("home/.switch"))
        #expect(try store.savedGeneral() == nil)

        settings.game.titleText = "Modded"
        try store.save(settings.general)
        try store.save(settings.game)
        #expect(try store.savedGeneral() == settings.general)
        #expect(try await store.load(detector: detector) == settings)
    }

    @Test func aFileMissingSomeFieldsKeepsTheOthers() throws {
        try folder.write("support/game-settings.json", #"{"gameApp": "/Apps/Game.app"}"#)
        try folder.write("support/settings.json", #"{"selectedGame": "totk", "general": {"keysFolder": "/keys"}}"#)
        let store = SettingsStore(paths: folder.paths, game: totk)

        #expect(try store.savedGame() == GameSettings(gameApp: "/Apps/Game.app"))
        #expect(try store.savedGeneral() == GeneralSettings(keysFolder: "/keys"))
    }

    @Test func aDamagedFileIsReportedInsteadOfReplaced() async throws {
        try folder.write("support/game-settings.json", "{ not json")
        let store = SettingsStore(paths: folder.paths, game: totk)

        #expect(throws: GraftError.self) { try store.savedGame() }
        await #expect(throws: GraftError.self) { try await store.load(detector: detector) }
        #expect(try folder.contents(of: "support") == ["game-settings.json"])
    }

    @Test func choosingAGameIsNotTheSameAsSavingSettings() throws {
        try SettingsStore.select(botw, root: folder.paths.root)

        #expect(SettingsStore.selection(root: folder.paths.root, catalog: GameCatalog(games: [totk, botw])) == .game(botw))
        #expect(try SettingsStore(paths: folder.paths, game: botw).savedGeneral() == nil)
    }

    @Test func anUnknownSelectedGameFallsBackToTheFirstGameOrNone() throws {
        try folder.write("support/settings.json", #"{"selectedGame": "gone"}"#)
        #expect(SettingsStore.selection(root: folder.paths.root, catalog: GameCatalog(games: [totk, ot0])) == .game(ot0))
        #expect(SettingsStore.selection(root: folder.paths.root, catalog: GameCatalog(games: [])) == .none)
    }

    @Test func dismissedImportsAreRememberedPerGame() throws {
        #expect(SettingsStore.dismissedImports(root: folder.paths.root).isEmpty)
        try SettingsStore.dismissImport(for: totk, root: folder.paths.root)
        try SettingsStore.select(botw, root: folder.paths.root)
        #expect(SettingsStore.dismissedImports(root: folder.paths.root) == ["totk"])
    }

    @Test func eachGameKeepsItsOwnSettingsAndSharesTheRest() async throws {
        let root = folder.url.appending(path: "Graft")
        func store(_ game: GameDefinition) -> SettingsStore {
            SettingsStore(paths: GraftPaths(root: root, support: root.appending(path: "games/\(game.id)"),
                                            gameData: folder.url.appending(path: game.id), gameLog: folder.url.appending(path: "\(game.id).log")),
                          game: game)
        }
        func files(_ game: GameDefinition, app: String) -> GameSettings {
            GameSettings(gameApp: app, workFolder: "/work/\(game.id)", baseGame: "/base/\(game.id)", update: "/update/\(game.id)")
        }
        try store(totk).save(GeneralSettings(macNativeGames: "/mng", keysFolder: "/keys-1"))
        try store(totk).save(files(totk, app: "/Apps/Tears of the Kingdom.app"))
        try store(botw).save(files(botw, app: "/Apps/Breath of the Wild.app"))

        #expect(SettingsStore.selection(root: root, catalog: GameCatalog(games: [totk])) == .game(totk))
        let saved = try JSONSerialization.jsonObject(with: Data(contentsOf: root.appending(path: "settings.json"))) as? [String: Any]
        #expect((saved?["general"] as? [String: Any])?["keysFolder"] as? String == "/keys-1")
        #expect(try await store(totk).load(detector: detector).game.workFolder == "/work/totk")
        let botwSettings = try await store(botw).load(detector: detector)
        #expect(botwSettings.game.gameApp == "/Apps/Breath of the Wild.app")
        #expect(botwSettings.general.keysFolder == "/keys-1")

        try SettingsStore.select(botw, root: root)
        #expect(SettingsStore.selection(root: root, catalog: GameCatalog(games: [totk, botw])) == .game(botw))
        #expect(try store(botw).savedGeneral()?.keysFolder == "/keys-1")
        #expect(try await store(totk).load(detector: detector).game.gameApp == "/Apps/Tears of the Kingdom.app")
    }
}
