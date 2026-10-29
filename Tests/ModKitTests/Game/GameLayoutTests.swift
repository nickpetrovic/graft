import Foundation
import Testing
@testable import ModKit

struct GameLayoutTests {
    let folder: TemporaryFolder

    init() throws {
        folder = try TemporaryFolder()
    }

    func writeMain(dataSize: UInt32 = 0x100000) throws {
        var header = Data(count: 0x100)
        func put(_ value: UInt32, at offset: Int) {
            withUnsafeBytes(of: value.littleEndian) { header.replaceSubrange(offset..<offset + 4, with: $0) }
        }
        put(0x41aa000, at: 0x34)
        put(dataSize, at: 0x38)
        put(0x481000, at: 0x3c)
        header.replaceSubrange(0x40..<0x54, with: (0..<20).map { UInt8($0) })
        let main = folder.url.appending(path: "work/totk/extracted/v121/exefs/main")
        try FileManager.default.createDirectory(at: main.deletingLastPathComponent(), withIntermediateDirectories: true)
        try header.write(to: main)
    }

    func load() throws -> GameLayout {
        try GameLayout.load(workFolder: folder.url.appending(path: "work"), gameApp: folder.path("Game.app"), game: totk)
    }

    @Test func theLayoutIsReadFromTheWorkFolder() throws {
        try folder.app("Game", version: "1.2.1")
        try writeMain()
        try folder.write("work/totk/rewritten/v121/main.fixups.tsv", "# DATA_OFF\t0x41aa000\n# KEY_PAGE_OFF\t0x472c000\nother line\n")

        let layout = try load()

        #expect(layout.version == "v121")
        #expect(layout.displayVersion == "1.2.1")
        #expect(layout.buildId == "000102030405060708090a0b0c0d0e0f10111213")
        #expect(layout.dataStart == 0x41aa000)
        #expect(layout.imageEnd == 0x41aa000 + 0x100000 + 0x481000)
        #expect(layout.keyPageStart == 0x472c000)
    }

    @Test func aWorkFolderWithoutThisVersionSaysWhatIsMissing() throws {
        try folder.app("Game", version: "1.2.1")

        let error = try #require(throws: GraftError.self) { try load() }

        #expect(error.message.contains("extracted/v121/exefs/main"))
        #expect(error.message.contains("Build the 1.2.1 game app"))
    }

    @Test func anAppWithoutAVersionIsRefused() throws {
        try folder.app("Game")
        let error = try #require(throws: GraftError.self) { try load() }
        #expect(error.message.contains("couldn't read the version"))
    }

    @Test func freeMemoryStartsOnThePageAfterTheImage() {
        #expect(layout121.freeStart == 0x472b000)
        #expect(GameLayout(version: "", displayVersion: "", buildId: "", dataStart: 0, imageEnd: 0x1001, keyPageStart: 0x3000).freeStart == 0x2000)
        #expect(layout121.isWritable(0x41aa000))
        #expect(!layout121.isWritable(0x41a9fff))
        #expect(!layout121.isWritable(0x472c000))
        #expect(layout121.isInsideMain(0x472bfff))
        #expect(!layout121.isInsideMain(0x472c000))
    }
}
