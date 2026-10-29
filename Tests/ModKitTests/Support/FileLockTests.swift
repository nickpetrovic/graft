import Foundation
import Testing
@testable import ModKit

struct FileLockTests {
    @Test func aSecondHolderWaitsAndThenGivesUp() async throws {
        let folder = try TemporaryFolder()
        let lock = folder.url.appending(path: "locks/apply.lock")

        let error = try await FileLock.holding(lock) {
            try await #require(throws: GraftError.self) {
                try await FileLock.holding(lock, timeout: .milliseconds(250)) { }
            }
        }

        #expect(error.message.hasPrefix("Another Graft task"))
        #expect(try await FileLock.holding(lock, timeout: .zero) { "free again" } == "free again")
    }

    @Test func theLockIsReleasedWhenTheWorkFails() async throws {
        let folder = try TemporaryFolder()
        let lock = folder.url.appending(path: "apply.lock")

        await #expect(throws: GraftError.self) { try await FileLock.holding(lock) { throw GraftError("failed") } }

        #expect(try await FileLock.holding(lock, timeout: .zero) { 1 } == 1)
    }
}
