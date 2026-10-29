import Foundation

public struct GameStop: Sendable, Equatable {
    public enum Hint: Sendable, Equatable {
        case wakeDisplay
        case rebuildForCodeMods
        case reinstallMods
    }

    public let reason: String
    public let hint: Hint?

    public static func read(log: URL, since: Date, game: GameDefinition) -> GameStop? {
        GameLog.text(of: log, changedSince: since).flatMap { parse($0, game: game) }
    }

    public static func parse(_ text: String, game: GameDefinition) -> GameStop? {
        let prefix = game.logLinePrefix + MacNativeGames.failure
        guard let line = text.split(whereSeparator: \.isNewline).last(where: { $0.hasPrefix(prefix) }) else { return nil }
        let reason = String(line.dropFirst(prefix.count))
        return GameStop(reason: reason, hint: hint(for: reason, game: game))
    }

    static func hint(for reason: String, game: GameDefinition) -> Hint? {
        func mentions(_ text: String) -> Bool { reason.range(of: text, options: .caseInsensitive) != nil }
        if mentions(MacNativeGames.displayLinkFailure) { return .wakeDisplay }
        if let variable = game.tkSharp?.codeMods?.launchVariable, mentions(variable) { return .rebuildForCodeMods }
        if mentions(MacNativeGames.romfsOverlayFailure) { return .reinstallMods }
        return nil
    }
}
