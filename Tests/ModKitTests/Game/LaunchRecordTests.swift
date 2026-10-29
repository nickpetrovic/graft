import Foundation
import Testing
@testable import ModKit

struct LaunchRecordTests {
    @Test func theLaunchTimeIsSavedToTheSecondAndCleared() throws {
        let folder = try TemporaryFolder()
        let launched = Date(timeIntervalSince1970: 1_800_000_000)

        LaunchRecord.save(launched, to: folder.paths)
        #expect(LaunchRecord.load(from: folder.paths) == launched)

        LaunchRecord.save(nil, to: folder.paths)
        #expect(LaunchRecord.load(from: folder.paths) == nil)
    }

    @Test func anUnreadableRecordIsIgnored() throws {
        let folder = try TemporaryFolder()
        try folder.write("support/last-launch.txt", "yesterday")
        #expect(LaunchRecord.load(from: folder.paths) == nil)
    }
}
