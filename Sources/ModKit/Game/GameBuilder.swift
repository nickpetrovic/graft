import Foundation

public struct GameBuilder: Sendable {
    public let settings: GraftSettings

    public init(settings: GraftSettings) {
        self.settings = settings
    }

    public static func status(forLine line: String) -> String {
        var text = line
        if let range = text.range(of: #"^\[\d{2}:\d{2}:\d{2}\]\s*"#, options: .regularExpression) {
            text.removeSubrange(range)
        }
        if let match = text.firstMatch(of: /^(\d)\/(\d) [a-z]+: (.*)$/) {
            return "Rebuilding the game app (step \(match.1) of \(match.2)): \(match.3)"
        }
        return "Rebuilding the game app: \(text.trimmingCharacters(in: .whitespaces))"
    }

    public func build(modFolder: URL?, progress: @escaping @Sendable (String) -> Void) async throws {
        guard let script = settings.definition.tkSharp?.buildScript else {
            throw GraftError("MacNativeGames has no way to rebuild \(settings.definition.name) yet.")
        }
        var arguments = [
            settings.game.baseGame,
            "-k", "\(settings.general.keysFolder)/prod.keys",
            "--update", settings.game.update,
            "--work", settings.game.workFolder,
            "-o", settings.game.gameApp,
        ]
        if let modFolder {
            arguments += ["--mod", modFolder.path]
        }
        let result = try await MacNativeGames(settings).run(
            script, arguments: arguments, inFolder: true,
            lineSource: .standardOutput) { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty { progress(trimmed) }
            }
        if result.status != 0 {
            let lines = result.errorText.split(whereSeparator: \.isNewline)
            let reason = lines.last { $0.contains(MacNativeGames.buildError) }.map(String.init)
                ?? lines.suffix(3).joined(separator: " ")
            throw GraftError("Rebuilding the game app failed: \(reason)")
        }
    }
}
