import Foundation
import Testing
@testable import ModKit

struct ChildProcessesTests {
    @Test func terminatingAllStopsEveryRunningProcessAndWhatItStarted() async throws {
        let folder = try TemporaryFolder()
        let children = ChildProcesses()
        let arguments = backgroundSleep(in: folder)
        let task = Task { try await ProcessRunner.run(URL(fileURLWithPath: "/bin/sh"), arguments: arguments, children: children) }
        let sleeper = try await backgroundPid(in: folder)
        #expect(children.count == 1)
        let stopped = ContinuousClock.now

        children.terminateAll()
        let result = try await task.value

        #expect(ContinuousClock.now - stopped < .seconds(10))
        #expect(result.status == SIGTERM)
        #expect(await hasExited(sleeper))
        #expect(children.count == 0)
    }

    @Test func aFinishedProcessIsNoLongerTracked() async throws {
        let children = ChildProcesses()
        _ = try await ProcessRunner.run(URL(fileURLWithPath: "/usr/bin/true"), arguments: [], children: children)
        #expect(children.count == 0)
    }
}

struct ChildProcessesStoppingTests {
    @Test func aProcessStartedAfterStoppingIsStoppedAtOnce() async throws {
        let children = ChildProcesses()
        children.terminateAll()
        let started = ContinuousClock.now

        let result = try await ProcessRunner.run(URL(fileURLWithPath: "/bin/sleep"), arguments: ["30"], children: children)

        #expect(ContinuousClock.now - started < .seconds(10))
        #expect(result.status == SIGTERM)
        #expect(children.count == 0)
    }
}
