import AppKit
import ModKit
import Observation
import UniformTypeIdentifiers

@MainActor
@Observable
final class LibraryModel {
    private(set) var catalog: GameCatalog
    private(set) var templates: GameTemplates
    private(set) var games: [LibraryGame] = []
    private(set) var suggestions: [GameSuggestion] = []
    private(set) var session: AppModel?
    private(set) var savedGeneral: GeneralSettings
    var editor: GameEditor?
    var removing: GameDefinition?
    var errorMessage: String?
    var sidebarVisible = true
    @ObservationIgnored private var suggestionSearch: Task<Void, Never>?
    @ObservationIgnored private var refreshPending = false

    init() {
        let catalog = GameCatalog.shared
        self.catalog = catalog
        templates = .shared
        savedGeneral = Self.loadGeneral()
        switch SettingsStore.selection(root: GraftPaths.standardRoot, catalog: catalog) {
        case .game(let game):
            open(AppModel(game: game))
        case .unreadable(_, let problem):
            if let first = catalog.games.first {
                let model = AppModel(game: first)
                model.errorMessage = problem
                open(model)
            }
        case .none:
            break
        }
        refreshGames()
    }

    private static func loadGeneral() -> GeneralSettings {
        (try? SettingsStore.savedGeneral(root: GraftPaths.standardRoot)) ?? SettingsDetector.detectGeneral()
    }

    var general: GeneralSettings { session?.settings.general ?? savedGeneral }

    var macNativeGames: URL? { MacNativeGames.presentFolder(general) }

    var isWorking: Bool { session?.isWorking ?? false }

    var locksControls: Bool { session?.locksControls ?? false }

    private func open(_ model: AppModel) {
        model.onGameAppChange = { [weak self] in self?.refreshGames() }
        model.onIdle = { [weak self] in self?.finishPendingRefresh() }
        session = model
    }

    func refresh() {
        catalog = .shared
        templates = .shared
        if isWorking {
            refreshPending = true
        } else {
            switch catalog.selection(keeping: session?.game.id) {
            case .game(let game): select(game)
            case .unreadable: break
            case .none: close()
            }
        }
        refreshGames()
    }

    private func finishPendingRefresh() {
        guard refreshPending else { return }
        refreshPending = false
        refresh()
    }

    private func close() {
        guard let session else { return }
        savedGeneral = session.settings.general
        self.session = nil
    }

    func refreshGames() {
        games = LibraryGame.all(current: session?.settings, catalog: catalog)
        let templates = templates
        let catalog = catalog
        suggestionSearch?.cancel()
        suggestionSearch = Task {
            let found = await Task.detached(priority: .utility) { GameSuggestion.all(templates: templates, catalog: catalog) }.value
            guard !Task.isCancelled else { return }
            suggestions = found
        }
    }

    func select(_ game: GameDefinition, app: String? = nil) {
        if let session {
            session.select(game, app: app)
        } else {
            do {
                try SettingsStore.select(game, root: GraftPaths.standardRoot)
            } catch {
                report("Could not switch to \(game.name): \(error.localizedDescription)")
                return
            }
            let model = AppModel(game: game, app: app)
            open(model)
            Task { await model.load() }
        }
    }

    func chooseGameToAdd() {
        guard !isWorking, let app = FilePicker.choose(.application) else { return }
        addGame(app)
    }

    func addGame(_ app: String) {
        guard !isWorking else { return }
        guard let identifier = AppBundle.bundleIdentifier(at: app) else {
            report("\(URL(fileURLWithPath: app).lastPathComponent) isn't a Mac app.")
            return
        }
        if let known = catalog.game(bundleIdentifier: identifier) {
            select(known, app: app)
            return
        }
        editor = GameEditor(draft: .make(app: app, portFolder: nil, macNativeGames: macNativeGames, templates: templates), app: app)
    }

    func add(_ suggestion: GameSuggestion) {
        guard !isWorking else { return }
        editor = GameEditor(draft: GameDraft(definition: suggestion.template.game(), origin: .template(suggestion.template.id)), app: suggestion.app)
    }

    func edit(_ game: GameDefinition) {
        editor = GameEditor(draft: .editing(game), app: nil)
    }

    func reviewTemplate(for game: GameDefinition) {
        guard let template = templates.update(for: game) else { return }
        editor = GameEditor(draft: .applying(template, to: game), app: nil)
    }

    func dismissTemplate(for game: GameDefinition) {
        guard let template = templates.update(for: game) else { return }
        var updated = game
        updated.template = template.reference
        save(updated)
    }

    func importGame() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.message = "Choose a game definition (.json) exported from Graft or shared with you."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            editor = GameEditor(draft: .importing(try GameStore.read(from: url), from: url, catalog: catalog), app: nil)
        } catch {
            report("Could not read \(url.lastPathComponent) as a game definition: \(error.localizedDescription)")
        }
    }

    func export(_ game: GameDefinition) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(game.name).json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try GameStore.export(game, to: url)
        } catch {
            report("Could not export \(game.name): \(error.localizedDescription)")
        }
    }

    func save(_ editing: GameEditor) -> Bool {
        let game = editing.draft.definition
        guard write(game) else { return false }
        editor = nil
        if editing.draft.isNew || editing.app != nil {
            select(game, app: editing.app)
        }
        refresh()
        return true
    }

    private func save(_ game: GameDefinition) {
        guard write(game) else { return }
        refresh()
    }

    private func write(_ game: GameDefinition) -> Bool {
        do {
            try GameStore.standard.save(game)
            return true
        } catch {
            report("Could not save \(game.name): \(error.localizedDescription)")
            return false
        }
    }

    func remove(_ game: GameDefinition) {
        guard !isWorking else { return }
        do {
            try GameStore.standard.remove(id: game.id)
        } catch {
            report("Could not remove \(game.name): \(error.localizedDescription)")
            return
        }
        refresh()
    }

    func revealDefinition(of game: GameDefinition) {
        NSWorkspace.shared.activateFileViewerSelecting([GameStore.standard.file(for: game.id)])
    }

    func revealGamesFolder() {
        NSWorkspace.shared.open(GameStore.standard.folder)
    }

    func showTemplatesFolder() {
        let folder = GameTemplates.userFolder
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        NSWorkspace.shared.open(folder)
    }

    func updateGeneral(_ change: (inout GeneralSettings) -> Void) {
        if let session {
            session.updateGeneral(change)
            return
        }
        var general = savedGeneral
        change(&general)
        guard general != savedGeneral else { return }
        do {
            try SettingsStore.save(general, root: GraftPaths.standardRoot)
            savedGeneral = general
        } catch {
            report("Could not save the settings: \(error.localizedDescription)")
        }
    }

    private func report(_ message: String) {
        if let session {
            session.errorMessage = message
        } else {
            errorMessage = message
        }
    }
}

struct GameEditor: Identifiable {
    let id = UUID()
    var draft: GameDraft
    let app: String?
}
