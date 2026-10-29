import Foundation
import Testing
@testable import ModKit

struct CrashReportTests {
    @Test func crashLogIsParsed() throws {
        let report = try #require(CrashReport.parse(try fixture("crash.log"), prefix: totk.logLinePrefix))
        #expect(report.signal == 10)
        #expect(report.programCounter == 0xf0014)
        #expect(report.frames == [0x1000004])
        #expect(report.place == "main+0xf0014")
    }

    @Test func aLogWithoutACrashHasNoReport() {
        #expect(CrashReport.parse("[totk] first presented frame\n", prefix: totk.logLinePrefix) == nil)
        #expect(CrashReport(programCounter: nil, frames: [], signal: 11).place == "an unknown place")
    }

    @Test func onlyALogWrittenSinceTheLaunchIsRead() throws {
        let folder = try TemporaryFolder()
        let log = try folder.write("totk.log", try fixture("crash.log"))
        #expect(CrashReport.read(log: log, since: .distantPast, prefix: totk.logLinePrefix) != nil)
        #expect(CrashReport.read(log: log, since: .now.addingTimeInterval(60), prefix: totk.logLinePrefix) == nil)
    }
}
