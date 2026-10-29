import Foundation
import Synchronization

public final class ChildProcesses: Sendable {
    private struct State {
        var running: [ObjectIdentifier: Process] = [:]
        var stopping = false
    }

    public static let shared = ChildProcesses()

    private let state = Mutex(State())

    public init() {}

    public var count: Int { state.withLock { $0.running.count } }

    func started(_ process: Process) {
        state.withLock { state in
            if state.stopping {
                process.terminate()
            } else {
                state.running[ObjectIdentifier(process)] = process
            }
        }
    }

    func finished(_ process: Process) {
        _ = state.withLock { $0.running.removeValue(forKey: ObjectIdentifier(process)) }
    }

    public func terminateAll() {
        state.withLock { state in
            state.stopping = true
            for process in state.running.values where process.isRunning {
                process.terminate()
            }
        }
    }
}
