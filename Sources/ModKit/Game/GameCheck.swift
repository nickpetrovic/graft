import Foundation

public enum GameCheck {
    public static func blockingProblems(for settings: GraftSettings, catalog: GameCatalog = .shared) -> [String] {
        let game = settings.definition
        var problems = catalog.unreadable[game.id].map { ["\($0) Graft is using what it read before. Fix the file, or edit the game to save it again."] } ?? []
        if game.unsupportedReason == nil, let macNativeGames = MacNativeGames(settings).presentFolder {
            problems += missingScripts(in: game, macNativeGames: macNativeGames)
        }
        return problems
    }

    public static func problems(in game: GameDefinition, macNativeGames: URL?) -> [String] {
        var problems: [String] = []
        if let folder = game.macNativeGamesFolder, let macNativeGames,
           !FileManager.default.fileExists(atPath: macNativeGames.appending(path: "games/\(folder)").path) {
            problems.append("Your MacNativeGames folder doesn't have games/\(folder).")
        }
        if game.unsupportedReason == nil, let macNativeGames {
            problems += missingScripts(in: game, macNativeGames: macNativeGames)
        }
        return problems
    }

    static func missingScripts(in game: GameDefinition, macNativeGames: URL) -> [String] {
        (game.mods.engineSettings?.scripts ?? []).compactMap { script in
            guard !script.path.isEmpty, !FileManager.default.fileExists(atPath: macNativeGames.appending(path: script.path).path) else { return nil }
            return "Your MacNativeGames folder doesn't have \(script.path), which Graft uses to \(script.purpose) for \(game.name)."
        }
    }
}
