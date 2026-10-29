import Foundation
import Testing
@testable import ModKit

struct LibraryImportTests {
    @Test func everyImportKeepsTheLibraryItReplaces() throws {
        let folder = try TemporaryFolder()
        try folder.write("home/Library/Application Support/tkmm2/.data2/state.db", "tkmm")
        let tkmm = LibraryImport(paths: folder.paths, home: folder.url.appending(path: "home"))
        let source = try #require(tkmm.findTKMMLibrary())
        #expect(tkmm.libraryIsEmpty)

        #expect(try tkmm.importTKMM(from: source) == nil)
        #expect(!tkmm.libraryIsEmpty)
        try folder.write("support/library/state.db", "edited in the manager")

        let firstBackup = try #require(try tkmm.importTKMM(from: source))
        let secondBackup = try #require(try tkmm.importTKMM(from: source))
        #expect(firstBackup != secondBackup)
        #expect(try String(contentsOf: firstBackup.appending(path: "state.db"), encoding: .utf8) == "edited in the manager")
        #expect(try String(contentsOf: folder.paths.library.appending(path: "state.db"), encoding: .utf8) == "tkmm")
    }
}
