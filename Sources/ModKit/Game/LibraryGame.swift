import Foundation

public struct LibraryGame: Sendable, Hashable, Identifiable {
    public let game: GameDefinition
    public let app: String?
    public let version: String?

    public var id: String { game.id }

    public var isSupported: Bool { game.unsupportedReason == nil }

    public var isInstalled: Bool { isSupported && app != nil }

    public var status: String {
        if !isSupported { return "Not supported yet" }
        guard app != nil else { return "No game app yet" }
        return version.map { "Version \($0)" } ?? "Version unknown"
    }

    public static func all(current: GraftSettings?, catalog: GameCatalog = .shared,
                           savedGame: (GameDefinition) -> GameSettings? = { try? SettingsStore(paths: .standard(for: $0), game: $0).savedGame() },
                           detector: (GameDefinition) -> SettingsDetector = { SettingsDetector(game: $0) }) -> [LibraryGame] {
        catalog.games.map { game in
            let saved = game.id == current?.definition.id ? current?.game : savedGame(game)
            let app = saved?.gameApp.nilIfEmpty.flatMap { FileManager.default.fileExists(atPath: $0) ? $0 : nil }
                ?? detector(game).findGameApp(near: [saved?.baseGame, saved?.update].compactMap { $0 })
            return LibraryGame(game: game, app: app, version: app.flatMap(AppBundle.shortVersion(at:)))
        }
    }
}

public struct GameSuggestion: Sendable, Hashable, Identifiable {
    public let template: GameTemplate
    public let app: String
    public let version: String?

    public var id: String { app }

    public static func all(templates: GameTemplates = .shared, catalog: GameCatalog = .shared,
                           folders: [URL] = SettingsDetector.appFolders()) -> [GameSuggestion] {
        let apps = folders.flatMap { folder in
            ((try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? [])
                .filter { $0.pathExtension == "app" }
        }
        var newest: [String: GameSuggestion] = [:]
        for app in apps {
            guard let identifier = AppBundle.bundleIdentifier(at: app.path), catalog.game(bundleIdentifier: identifier) == nil,
                  let template = templates.template(bundleIdentifier: identifier) else { continue }
            let suggestion = GameSuggestion(template: template, app: app.path, version: AppBundle.shortVersion(at: app.path))
            if let current = newest[template.id], !suggestion.isNewer(than: current) { continue }
            newest[template.id] = suggestion
        }
        return newest.values.sorted { $0.template.definition.name.localizedStandardCompare($1.template.definition.name) == .orderedAscending }
    }

    func isNewer(than other: GameSuggestion) -> Bool {
        (version ?? "").compare(other.version ?? "", options: .numeric) == .orderedDescending
    }
}
