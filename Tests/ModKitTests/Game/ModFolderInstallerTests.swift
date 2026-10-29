import Foundation
import Testing
@testable import ModKit

struct ModFolderInstallerTests {
    let folder: TemporaryFolder
    let installer: ModFolderInstaller

    init() throws {
        folder = try TemporaryFolder()
        try folder.write("MacNativeGames/games/totk/scripts/make_mod_manifest.py", """
            if [ -f "$1/empty" ]; then echo "nothing written: the folder replaces or adds no file" >&2; exit 1; fi
            printf 'file\\t%s\\n' "$(ls "$1" | tr '\\n' ' ')" > "$1/manifest.tsv"
            echo "manifest.tsv: 1 files (1 replaced, 0 added)"
            """)
        let settings = GraftSettings(definition: totk, general: GeneralSettings(macNativeGames: folder.url.appending(path: "MacNativeGames").path),
                                     game: GameSettings(gameApp: folder.url.appending(path: "Game.app").path, workFolder: folder.url.appending(path: "work").path))
        let python = folder.url.appending(path: "work/totk/.venv/bin/python")
        try FileManager.default.createDirectory(at: python.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: python, withDestinationURL: URL(fileURLWithPath: "/bin/sh"))
        installer = ModFolderInstaller(settings: settings, version: layout121.version, paths: folder.paths)
    }

    func romfs(_ name: String) throws -> URL {
        try folder.write("merged-\(name)/romfs/\(name).bin", name).deletingLastPathComponent()
    }

    @Test func installsAndReplacesItsOwnFolderWithoutBackups() async throws {
        let first = try await installer.install(romfs: try romfs("one"))
        #expect(first == "Installed data mods: 1 file (1 replaced, 0 added).")
        let second = try await installer.install(romfs: try romfs("two"))
        #expect(!second.contains("moved"))
        #expect(try folder.contents(of: "game/mods") == ["v121"])
        #expect(try folder.contents(of: "game/mods/v121") == ["manifest.tsv", "two.bin"])
    }

    @Test func folderItDidNotWriteIsMovedAside() async throws {
        try folder.write("game/mods/v121/manifest.tsv", "copied by hand")
        try folder.write("game/mods/v121/mine.bin", "mine")
        let message = try await installer.install(romfs: nil)
        #expect(message.contains("moved"))
        let entries = try folder.contents(of: "game/mods")
        #expect(entries.count == 1)
        #expect(entries[0].hasPrefix("v121.backup-"))
        #expect(try folder.contents(of: "game/mods/\(entries[0])") == ["manifest.tsv", "mine.bin"])
    }

    @Test func folderChangedByHandAfterInstallIsMovedAside() async throws {
        _ = try await installer.install(romfs: try romfs("one"))
        try folder.write("game/mods/v121/manifest.tsv", "edited")
        _ = try await installer.install(romfs: try romfs("two"))
        let entries = try folder.contents(of: "game/mods")
        #expect(entries.contains("v121"))
        #expect(entries.contains { $0.hasPrefix("v121.backup-") })
    }

    @Test func fileAddedByHandAfterInstallIsMovedAside() async throws {
        _ = try await installer.install(romfs: try romfs("one"))
        try folder.write("game/mods/v121/extra.bin", "added by hand")
        _ = try await installer.install(romfs: try romfs("two"))
        let entries = try folder.contents(of: "game/mods")
        #expect(entries.contains("v121"))
        #expect(entries.contains { $0.hasPrefix("v121.backup-") })
    }

    @Test func turningDataModsOffRemovesOnlyItsOwnFolder() async throws {
        _ = try await installer.install(romfs: try romfs("one"))
        let message = try await installer.install(romfs: nil)
        #expect(message == "No data mods are on.")
        #expect(try folder.contents(of: "game/mods").isEmpty)
    }

    @Test func modsThatChangeNothingAreNotAnError() async throws {
        let source = try romfs("one")
        try folder.write("merged-one/romfs/empty")
        let message = try await installer.install(romfs: source)
        #expect(message.contains("change nothing"))
        #expect(try folder.contents(of: "game/mods").isEmpty)
    }

    @Test func theManifestSummaryCountsReplacedAndAddedFiles() throws {
        let manifest = try folder.write("manifest.tsv", "# header\na.bin\tabc\nb.bin\t-\nc.bin\tdef\n")
        #expect(ModFolderInstaller.summary(ofManifest: manifest) == "3 files (2 replaced, 1 added)")
    }

    @Test func systemFilesAreNotPartOfTheFolder() {
        #expect(ModFolderInstaller.isSystemFile("romfs/._a.bin"))
        #expect(ModFolderInstaller.isSystemFile(".DS_Store"))
        #expect(ModFolderInstaller.isSystemFile("__MACOSX/romfs/a.bin"))
        #expect(ModFolderInstaller.isSystemFile("Thumbs.db"))
        #expect(!ModFolderInstaller.isSystemFile("romfs/a.bin"))
    }

    @Test func aFinderFileInTheFolderDoesNotCountAsAChange() async throws {
        _ = try await installer.install(romfs: try romfs("one"))
        try folder.write("game/mods/v121/.DS_Store", "finder")
        _ = try await installer.install(romfs: try romfs("two"))
        #expect(try folder.contents(of: "game/mods") == ["v121"])
    }
}
