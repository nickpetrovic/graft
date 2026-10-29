import Foundation
import Testing
@testable import ModKit

struct StampedCacheTests {
    @Test func aCachedValueIsReadAgainOnlyWhenItsFilesChange() throws {
        let folder = try TemporaryFolder()
        let first = try folder.write("a.json", "1")
        let cache = StampedCache<String>()
        var loads = 0
        func read(_ files: [URL]) -> String {
            cache.value(for: files) {
                loads += 1
                return files.map { (try? String(contentsOf: $0, encoding: .utf8)) ?? "" }.joined()
            }
        }

        #expect(read([first]) == "1")
        #expect(read([first]) == "1")
        #expect(loads == 1)

        try folder.write("a.json", "22")
        #expect(read([first]) == "22")
        #expect(loads == 2)

        let second = try folder.write("b.json", "3")
        #expect(read([first, second]) == "223")
        #expect(loads == 3)

        try FileManager.default.removeItem(at: second)
        #expect(read([first]) == "22")
        #expect(loads == 4)
    }
}

struct FileStampTests {
    @Test func aLinkedFileIsStampedByWhatItPointsTo() throws {
        let folder = try TemporaryFolder()
        let target = try folder.write("target.json", "1")
        let link = folder.url.appending(path: "link.json")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        let before = FileStamp(link)

        try folder.write("target.json", "22")

        #expect(FileStamp(link) != before)
        #expect(FileStamp(link) == FileStamp(target))
    }
}
