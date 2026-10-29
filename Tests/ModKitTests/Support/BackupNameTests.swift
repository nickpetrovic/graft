import Foundation
import Testing
@testable import ModKit

struct BackupNameTests {
    @Test func twoBackupsInTheSameSecondGetDifferentNames() throws {
        let folder = try TemporaryFolder()
        let date = Date(timeIntervalSince1970: 2 * 86_400)
        let first = BackupName.unused(in: folder.url, prefix: "x", date: date)
        try FileManager.default.createDirectory(at: first, withIntermediateDirectories: true)
        let second = BackupName.unused(in: folder.url, prefix: "x", date: date)
        #expect(first.lastPathComponent.hasPrefix("x-1970010"))
        #expect(second.lastPathComponent == first.lastPathComponent + "-2")
    }
}
