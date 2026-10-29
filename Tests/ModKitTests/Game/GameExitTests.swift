import Foundation
import Testing
@testable import ModKit

struct GameExitTests {
    @Test func aCrashIsTracedToTheModThatWroteTheCode() throws {
        let folder = try TemporaryFolder()
        let log = try folder.write("totk.log", try fixture("crash.log"))
        var state = ApplyState()
        state.recordOwners([0xf0014: "cave"])

        guard case .crashed(let report, let modId)? = GameExit.read(log: log, since: .distantPast, game: totk, state: state) else {
            Issue.record("expected a crash")
            return
        }
        #expect(modId == "cave")
        #expect(report.place == "main+0xf0014")
    }

    @Test func aStopIsReportedWhenThereIsNoCrash() throws {
        let folder = try TemporaryFolder()
        let log = try folder.write("totk.log", "[totk] FAIL: native display link initialization\n")

        #expect(GameExit.read(log: log, since: .distantPast, game: totk, state: ApplyState())
            == .stopped(GameStop(reason: "native display link initialization", hint: .wakeDisplay)))
        #expect(GameExit.read(log: folder.url.appending(path: "missing.log"), since: .distantPast, game: totk, state: ApplyState()) == nil)
    }
}
