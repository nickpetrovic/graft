import Foundation

public struct SettingsStore: Sendable {
    public let paths: GraftPaths
    public let game: GameDefinition

    public init(paths: GraftPaths, game: GameDefinition) {
        self.paths = paths
        self.game = game
    }

    struct AppFile: Codable {
        var selectedGame: String?
        var general: GeneralSettings?
        var dismissedImports: Set<String>?
    }

    public static func selection(root: URL, catalog: GameCatalog = .shared) -> CatalogSelection {
        catalog.selection(keeping: (try? JSONFile.read(AppFile.self, from: GraftPaths.appSettingsFile(root: root)))?.selectedGame)
    }

    public static func select(_ game: GameDefinition, root: URL) throws {
        let url = GraftPaths.appSettingsFile(root: root)
        var file = try JSONFile.read(AppFile.self, from: url) ?? AppFile()
        file.selectedGame = game.id
        try JSONFile.write(file, to: url)
    }

    public static func dismissedImports(root: URL) -> Set<String> {
        (try? JSONFile.read(AppFile.self, from: GraftPaths.appSettingsFile(root: root)))?.dismissedImports ?? []
    }

    public static func dismissImport(for game: GameDefinition, root: URL) throws {
        let url = GraftPaths.appSettingsFile(root: root)
        var file = try JSONFile.read(AppFile.self, from: url) ?? AppFile()
        file.dismissedImports = (file.dismissedImports ?? []).union([game.id])
        try JSONFile.write(file, to: url)
    }

    public func savedGeneral() throws -> GeneralSettings? {
        try Self.savedGeneral(root: paths.root)
    }

    public static func savedGeneral(root: URL) throws -> GeneralSettings? {
        try JSONFile.read(AppFile.self, from: GraftPaths.appSettingsFile(root: root))?.general
    }

    public static func save(_ general: GeneralSettings, root: URL) throws {
        let url = GraftPaths.appSettingsFile(root: root)
        var file = try JSONFile.read(AppFile.self, from: url) ?? AppFile()
        file.general = general
        try JSONFile.write(file, to: url)
    }

    public func savedGame() throws -> GameSettings? {
        try JSONFile.read(GameSettings.self, from: paths.settingsFile)
    }

    public func load(detector: SettingsDetector? = nil) async throws -> GraftSettings {
        try await loadDetecting(detector).settings
    }

    public func loadSavingDetected(detector: SettingsDetector? = nil) async throws -> GraftSettings {
        let loaded = try await loadDetecting(detector)
        if !loaded.generalWasSaved { try save(loaded.settings.general) }
        if !loaded.gameWasSaved { try save(loaded.settings.game) }
        return loaded.settings
    }

    private func loadDetecting(_ detector: SettingsDetector?) async throws -> (settings: GraftSettings, generalWasSaved: Bool, gameWasSaved: Bool) {
        let general = try savedGeneral()
        let game = try savedGame()
        let detected = general == nil || game == nil ? await (detector ?? SettingsDetector(game: self.game)).detect() : nil
        let settings = GraftSettings(definition: self.game,
                                     general: general ?? detected?.general ?? GeneralSettings(),
                                     game: game ?? detected?.game ?? GameSettings())
        return (settings, general != nil, game != nil)
    }

    public func save(_ general: GeneralSettings) throws {
        try Self.save(general, root: paths.root)
    }

    public func save(_ game: GameSettings) throws {
        try JSONFile.write(game, to: paths.settingsFile)
    }
}

extension SettingsStore {
    public func using(gameApp app: String) async throws -> GraftSettings {
        var settings = try await loadSavingDetected()
        guard settings.game.gameApp != app else { return settings }
        let previous = settings.game
        settings.game.gameApp = app
        settings.game.remember(previous)
        try save(settings.game)
        return settings
    }
}
