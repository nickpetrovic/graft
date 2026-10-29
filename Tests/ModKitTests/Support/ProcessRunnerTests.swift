import Foundation
import Testing
@testable import ModKit

struct ProcessRunnerTests {
    @Test func outputIsSplitIntoLines() async throws {
        let lines = StepLog()
        let result = try await ProcessRunner.run(URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", "printf 'one\\n\\ntwo\\nthree'; printf oops >&2"],
                                                 lineSource: .standardOutput) { lines.add($0) }
        #expect(result.status == 0)
        #expect(lines.all == ["one", "", "two", "three"])
        #expect(result.outputText == "one\n\ntwo\nthree")
        #expect(result.errorText == "oops")
    }

    @Test func theExitStatusAndWorkingFolderAreKept() async throws {
        let folder = try TemporaryFolder()
        let result = try await ProcessRunner.run(URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", "pwd; exit 3"], workingDirectory: folder.url)
        #expect(result.status == 3)
        #expect(URL(fileURLWithPath: result.outputText.trimmingCharacters(in: .newlines)).resolvingSymlinksInPath() == folder.url.resolvingSymlinksInPath())
    }

    @Test func theLastLinesOfBothOutputsExplainAFailure() {
        let result = ProcessResult(status: 1, output: Data("step 1\nstep 2\n".utf8), errorText: "warning\nError: no space left\n")
        #expect(result.lastLines(2) == "step 1 step 2")
        #expect(result.lastLines(3) == "Error: no space left step 1 step 2")
    }

    @Test func cancellingStopsTheProcessAndWhatItStarted() async throws {
        let folder = try TemporaryFolder()
        let arguments = backgroundSleep(in: folder)
        let started = ContinuousClock.now
        let task = Task { try await ProcessRunner.run(URL(fileURLWithPath: "/bin/sh"), arguments: arguments, children: ChildProcesses()) }
        let sleeper = try await backgroundPid(in: folder)

        task.cancel()
        _ = try? await task.value

        #expect(ContinuousClock.now - started < .seconds(10))
        #expect(await hasExited(sleeper))
    }
}
