import Foundation
import Testing
@testable import ModKit

struct SettingsDetectorTests {
    let folder: TemporaryFolder

    init() throws {
        folder = try TemporaryFolder()
    }

    func detector(_ game: GameDefinition = totk, protectedFolders: Bool = false) -> SettingsDetector {
        SettingsDetector(game: game, home: folder.url.appending(path: "home"), applications: folder.url.appending(path: "Applications"),
                         includeProtectedFolders: protectedFolders)
    }

    func paths(_ apps: [String]) -> [String] {
        apps.map { URL(fileURLWithPath: $0).standardizedFileURL.path }
    }

    @Test func gameFilesAreFoundByTitleIdAndTheNewestUpdateWins() async throws {
        try folder.write("home/Games/Switch/TotK/Zelda TotK [0100F2C0115B6000][v0].xci")
        try folder.write("home/Games/Switch/TotK/Zelda TotK [0100F2C0115B6800][v262144].nsp")
        try folder.write("home/Downloads/Zelda TotK [0100F2C0115B6800][v393216].nsp")
        try folder.write("home/.switch/prod.keys")
        try folder.write("home/Projects/MacNativeGames/build_app.py")

        let automatic = await detector().detect()
        #expect(automatic.game.update.hasSuffix("[0100F2C0115B6800][v262144].nsp"))

        let detected = await detector(protectedFolders: true).detect()
        #expect(detected.game.baseGame.hasSuffix("[0100F2C0115B6000][v0].xci"))
        #expect(detected.game.update.hasSuffix("Downloads/Zelda TotK [0100F2C0115B6800][v393216].nsp"))
        #expect(detected.general.keysFolder.hasSuffix("home/.switch"))
        #expect(detected.general.macNativeGames.hasSuffix("home/Projects/MacNativeGames"))
        #expect(detected.game.gameApp.isEmpty)
    }

    @Test func keysNextToTheGameFileAndTheWorkFolderNextToItAreFound() async throws {
        try folder.write("home/Games/Switch/TotK [0100F2C0115B6000][v0].xci")
        try folder.write("home/Games/Switch/prod.keys")
        try folder.write("home/Games/Switch/TOTK_build/totk/extracted/v121/exefs/main")

        let detected = await detector().detect()

        #expect(detected.general.keysFolder.hasSuffix("home/Games/Switch"))
        #expect(detected.game.workFolder.hasSuffix("home/Games/Switch/TOTK_build"))
    }

    @Test func aPortsWorkFolderInsideMacNativeGamesIsFound() async throws {
        try folder.write("home/Projects/MacNativeGames/build_app.py")
        try folder.write("home/Projects/MacNativeGames/games/ot0/OT0_build/extracted/v105/romfs/a.bin")

        let detected = await detector(ot0).detect()

        #expect(detected.game.workFolder.hasSuffix("MacNativeGames/games/ot0/OT0_build"))
    }

    @Test func theWorkFolderIsReadFromTheApp() async throws {
        let profile = try JSONDecoder().decode(GameDefinition.self, from: Data("""
            {"id": "filegame", "name": "File Game", "titleId": "0100000000000000", "engine": "none",
             "app": {"bundleIdentifier": "xyz.petrovic.graft.tests.filegame", "workFolderKey": "WorkFolder"}}
            """.utf8))
        try folder.app("home/Applications/File Game", identifier: "xyz.petrovic.graft.tests.filegame", info: ["WorkFolder": "/Games/port/work"])

        let found = await detector(profile).detect()

        #expect(found.game.gameApp.hasSuffix("File Game.app"))
        #expect(found.game.workFolder == "/Games/port/work")
    }

    @Test func everyAppOfTheGameIsFoundInTheUsualFolders() throws {
        let first = try folder.app("home/Games/macOS/Tears of the Kingdom", identifier: totk.bundleIdentifier, version: "1.2.1")
        let second = try folder.app("Applications/TotK 1.4.3", identifier: totk.bundleIdentifier, version: "1.4.3")
        try folder.app("Applications/BotW", identifier: botw.bundleIdentifier, version: "1.6.0")
        let nextToGame = try folder.app("Dumps/TotK/Tears of the Kingdom", identifier: totk.bundleIdentifier, version: "1.4.3")
        let baseGame = try folder.write("Dumps/TotK/TotK [0100F2C0115B6000][v0].xci").path

        #expect(paths(detector().findGameApps()) == paths([first, second]))
        #expect(paths(detector().findGameApps(near: [baseGame])) == paths([nextToGame, first, second]))
        #expect(detector().findGameApp(near: [baseGame]).map { paths([$0]) } == paths([nextToGame]))
        #expect(detector().findGameApp().map { paths([$0]) } == paths([first]))
    }

    @Test func updateFilesAreListedFromTheGamesFolderAndNextToChosenFiles() throws {
        let inGames = try folder.write("home/Games/a/b/c/update.NSP").path
        try folder.write("home/Games/a/b/c/d/too-deep.nsp")
        let nearby = try folder.write("Dumps/other.xci").path
        try folder.write("Dumps/readme.txt")

        let found = paths(detector().updateFiles(near: [folder.path("Dumps/base.xci"), ""]).map(\.path))

        #expect(found == paths([inGames, nearby]))
    }

    @Test func theUpdateVersionIsReadFromTheFileName() {
        #expect(SettingsDetector.version(inFileName: "TOTK [0100F2C0115B6800][V393216].NSP") == 393216)
        #expect(SettingsDetector.version(inFileName: "update.nsp") == 0)
    }
}

struct SettingsDetectorTitleIdTests {
    @Test func aTitleIdTypedInLowercaseStillFindsTheGameFiles() async throws {
        let folder = try TemporaryFolder()
        try folder.write("home/Games/TotK [0100F2C0115B6000][v0].xci")
        try folder.write("home/Games/TotK [0100F2C0115B6800][v393216].nsp")
        var game = totk
        game.titleId = "0100f2c0115b6000"
        game.updateTitleId = "0100f2c0115b6800"

        let found = await SettingsDetector(game: game, home: folder.url.appending(path: "home"), applications: folder.url.appending(path: "Applications")).detect()

        #expect(found.game.baseGame.hasSuffix("[v0].xci"))
        #expect(found.game.update.hasSuffix("[v393216].nsp"))
    }
}
