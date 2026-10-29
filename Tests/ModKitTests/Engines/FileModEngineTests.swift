import Foundation
import Testing
@testable import ModKit

struct FileModEngineTests {
    let folder: TemporaryFolder
    let engine: FileModEngine
    let definition: GameDefinition

    init() throws {
        folder = try TemporaryFolder()
        let json = """
            {"id": "filegame", "name": "File Game", "titleId": "0100000000000000",
             "app": {"bundleIdentifier": "xyz.petrovic.graft.tests.filegame", "workFolderKey": "WorkFolder"},
             "workTree": "",
             "mods": {"engine": "files", "pakFolder": "Game/Content/Paks/~mods", "manifestScript": "games/filegame/scripts/manifest.sh",
                      "python": "venv/bin/python", "appGameFolder": "Contents/Resources/game"}}
            """
        definition = try JSONDecoder().decode(GameDefinition.self, from: Data(json.utf8))
        try folder.write("port/work/venv/bin/python", "#!/bin/sh\nexec /bin/sh \"$@\"\n", executable: true)
        try folder.write("mng/games/filegame/scripts/manifest.sh",
                         "test -f \"$3/romfs.bin\" || exit 3\ncd \"$1\" && find . -type f ! -name manifest.tsv | sort > manifest.tsv\n")
        try folder.write("Game.app/Contents/Resources/game/extracted/v104/romfs/romfs.bin")
        try folder.app("Game", version: "1.0.4")
        let settings = GraftSettings(definition: definition, general: GeneralSettings(macNativeGames: folder.url.appending(path: "mng").path),
                                     game: GameSettings(gameApp: folder.url.appending(path: "Game.app").path,
                                                        workFolder: folder.url.appending(path: "port/work").path))
        engine = FileModEngine(settings: settings, paths: folder.paths, fileMods: try #require(definition.fileMods))
    }

    @discardableResult
    func modFolder(_ name: String, _ files: [String: String]) throws -> URL {
        for (path, text) in files { try folder.write("downloads/\(name)/\(path)", text) }
        return folder.url.appending(path: "downloads/\(name)", directoryHint: .isDirectory)
    }

    @Test func aFolderWithRomfsAndLoosePaksAreBothAdded() async throws {
        let withRomfs = try modFolder("Hard Mode", ["romfs/Game/Content/Paks/~mods/Hard_P.pak": "hard"])
        let loosePak = try modFolder("Detailed Skill Descriptions-46-1-0-1765", ["Skills_P.pak": "skills", "readme.txt": "hi"])

        _ = try await engine.add(withRomfs) { _ in }
        let added = try await engine.add(loosePak) { _ in }

        #expect(added.name == "Detailed Skill Descriptions")
        #expect(added.mods.map(\.name) == ["Hard Mode", "Detailed Skill Descriptions"])
        #expect(added.mods.map(\.dataFiles) == [1, 1])
        #expect(FileManager.default.fileExists(atPath: folder.paths.library.appending(path: "\(added.mods[1].id)/romfs/Game/Content/Paks/~mods/Skills_P.pak").path))
    }

    @Test func aZipIsUnpacked() async throws {
        let source = try modFolder("Speed", ["~mods/Speed_P.pak": "speed"])
        let zip = folder.url.appending(path: "Speed-20-1-0.zip")
        let result = try await ProcessRunner.run(URL(fileURLWithPath: "/usr/bin/ditto"), arguments: ["-c", "-k", source.path, zip.path])
        #expect(result.status == 0)

        let added = try await engine.add(zip) { _ in }

        #expect(added.name == "Speed")
        #expect(added.mods.first?.dataFiles == 1)
    }

    @Test func aSinglePakFileIsAdded() async throws {
        let pak = try folder.write("downloads/PS5Buttons_P.pak", "font")

        let added = try await engine.add(pak) { _ in }

        #expect(added.name == "PS5Buttons_P")
        #expect(FileManager.default.fileExists(atPath: folder.paths.library.appending(path: "\(added.mods[0].id)/romfs/Game/Content/Paks/~mods/PS5Buttons_P.pak").path))
    }

    @Test func aModMadeForAnotherGameIsRefused() async throws {
        var refusing = engine
        refusing.otherGames = [KnownGame(name: "Breath of the Wild", signatures: try #require(botw.modSignatures))]
        let source = try modFolder("Big Sword", ["romfs/Actor/Pack/Weapon_Sword_070.sbactorpack": "sword"])

        let error = await #expect(throws: GraftError.self) { try await refusing.add(source) { _ in } }

        #expect(error?.message == "'Big Sword' is a Breath of the Wild mod, so it can't be added to File Game.")
        #expect(try await refusing.list().isEmpty)
    }

    @Test func somethingWithoutGameFilesIsRefused() async throws {
        let notAMod = try modFolder("Notes", ["readme.txt": "hi"])
        await #expect(throws: GraftError.self) { try await engine.add(notAMod) { _ in } }
    }

    @Test func anotherCopyReplacesTheFirstAndKeepsItsPlaceAndSwitch() async throws {
        let store = ModSetupStore(settings: engine.settings, paths: folder.paths)
        _ = try await engine.add(try modFolder("A", ["a.pak": "1"])) { _ in }
        let b = try await engine.add(try modFolder("B", ["b.pak": "1"])) { _ in }
        var setup = try store.current(library: b.mods)
        setup.setEnabled(b.id, false)
        setup.move(b.id, to: 0)
        try store.save(setup)

        let again = try await engine.add(try modFolder("B", ["b.pak": "2", "b.utoc": "2"])) { _ in }
        try store.recordAdded(again)
        let shown = try store.current(library: again.mods).applied(to: again.mods)

        #expect(again.replacedIds == [b.id])
        #expect(shown.map(\.name) == ["B", "A"])
        #expect(shown.map(\.enabled) == [false, true])
        #expect(shown.first?.dataFiles == 2)
    }

    @Test func applyCombinesModsIntoTheGamesModFolderSoTheHigherOneWins() async throws {
        let top = try await engine.add(try modFolder("Top", ["romfs/shared.txt": "top", "romfs/top.txt": "top"])) { _ in }
        _ = try await engine.add(try modFolder("Bottom", ["romfs/shared.txt": "bottom", "romfs/bottom.txt": "bottom"])) { _ in }
        #expect(top.mods.first?.name == "Top")

        let outcome = try await engine.apply(try await engine.list(), force: false) { _ in }

        let installed = folder.paths.modsFolder(version: "v104")
        #expect(try String(contentsOf: installed.appending(path: "shared.txt"), encoding: .utf8) == "top")
        #expect(FileManager.default.fileExists(atPath: installed.appending(path: "bottom.txt").path))
        #expect(outcome.dataSummary.hasPrefix("Installed data mods: 3 files"))
        #expect(FileManager.default.fileExists(atPath: folder.paths.gameData.appending(path: "mods/.v104.managed-by-graft").path))

        let off = try await engine.apply(outcome.mods.map { $0.configured(position: $0.position, enabled: false, options: [:]) }, force: false) { _ in }
        #expect(off.dataSummary == "No mods are on.")
        #expect(!FileManager.default.fileExists(atPath: installed.path))
    }

    @Test func aModFolderGraftDidNotWriteIsKeptAsABackup() async throws {
        try folder.write("game/mods/v104/mine.txt", "mine")
        _ = try await engine.add(try modFolder("Top", ["romfs/top.txt": "top"])) { _ in }

        let outcome = try await engine.apply(try await engine.list(), force: false) { _ in }

        #expect(outcome.dataSummary.contains("Your earlier mod folder was moved to"))
        let backups = try folder.contents(of: "game/mods").filter { $0.hasPrefix("v104.backup") }
        #expect(backups.count == 1)
        #expect(try String(contentsOf: folder.url.appending(path: "game/mods/\(backups[0])/mine.txt"), encoding: .utf8) == "mine")
    }

    @Test func removingAModDeletesItsFiles() async throws {
        let added = try await engine.add(try modFolder("Gone", ["romfs/gone.txt": "gone"])) { _ in }

        let remaining = try await engine.remove(added.id)

        #expect(remaining.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: folder.paths.library.appending(path: added.id).path))
    }

    @Test func theModNameDropsTheDownloadNumbersButKeepsDotsInFolderNames() throws {
        #expect(FileModEngine.modName(of: URL(fileURLWithPath: "/Downloads/Detailed Skills-46-1-0-1765.zip")) == "Detailed Skills")
        #expect(FileModEngine.modName(of: URL(fileURLWithPath: "/Downloads/PS5Buttons_P.pak")) == "PS5Buttons_P")
        let dotted = try modFolder("Hard Mode v1.2", ["romfs/hard.txt": "hard"])
        #expect(FileModEngine.modName(of: URL(filePath: dotted.path, directoryHint: .notDirectory)) == "Hard Mode v1.2")
    }

    @Test func systemFilesInAModAreIgnored() async throws {
        let source = try modFolder("Mac Copy", ["romfs/a.txt": "a", "romfs/._a.txt": "", "romfs/.DS_Store": "", "__MACOSX/romfs/b.txt": "b"])

        let added = try await engine.add(source) { _ in }

        #expect(added.mods.first?.dataFiles == 1)
    }
}
