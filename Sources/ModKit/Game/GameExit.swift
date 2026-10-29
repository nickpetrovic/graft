import Foundation

public enum GameExit: Sendable, Equatable {
    case crashed(CrashReport, modId: String?)
    case stopped(GameStop)

    public static func read(log: URL, since: Date, game: GameDefinition, state: ApplyState) -> GameExit? {
        if let report = CrashReport.read(log: log, since: since, prefix: game.logLinePrefix) {
            return .crashed(report, modId: state.crashOwner(report))
        }
        return GameStop.read(log: log, since: since, game: game).map(GameExit.stopped)
    }
}
