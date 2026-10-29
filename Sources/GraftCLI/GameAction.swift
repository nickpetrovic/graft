import Foundation
import ModKit

enum GameAction: String, CaseIterable {
    case add
    case `import`
    case export
    case remove
    case check
    case templates

    static let noGames = "No games yet. Add one with graft game add <game app>, or in Graft with Add Game."

    var synopsis: String {
        switch self {
        case .add: "game add <game app>"
        case .import: "game import <file>"
        case .export: "game export <id> <file>"
        case .remove: "game remove <id>"
        case .check: "game check"
        case .templates: "game templates"
        }
    }

    var summary: String {
        switch self {
        case .add: "add a game from its app, or another version of a game you have"
        case .import: "add a game from a definition file, or replace the one with its id"
        case .export: "save a game's definition to a file"
        case .remove: "remove a game; its mods and load orders stay"
        case .check: "check every game's definition"
        case .templates: "list the game templates"
        }
    }

    var arguments: Int {
        switch self {
        case .add, .import, .remove: 1
        case .export: 2
        case .check, .templates: 0
        }
    }

    func run(_ arguments: [String], root: URL) async throws {
        let catalog = GameCatalog.shared
        let templates = GameTemplates.shared
        let general = try SettingsStore.savedGeneral(root: root) ?? SettingsDetector.detectGeneral()
        let macNativeGames = MacNativeGames.presentFolder(general)
        switch self {
        case .add:
            let app = URL(fileURLWithPath: arguments[0]).standardizedFileURL.path
            guard let identifier = AppBundle.bundleIdentifier(at: app) else { fail("\(arguments[0]) isn't a Mac app") }
            if let existing = catalog.game(bundleIdentifier: identifier) {
                try SettingsStore.select(existing, root: root)
                _ = try await SettingsStore(paths: .standard(for: existing), game: existing).using(gameApp: app)
                print("added \(arguments[0]) as a version of \(existing.name) (\(existing.id)) and switched to it")
                return
            }
            let draft = GameDraft.make(app: app, portFolder: nil, macNativeGames: macNativeGames, templates: templates)
            try await add(draft, app: app, catalog: catalog, root: root)
        case .import:
            let file = URL(fileURLWithPath: arguments[0])
            let draft = GameDraft.importing(try GameStore.read(from: file), from: file, catalog: catalog)
            try await add(draft, app: nil, catalog: catalog, root: root)
        case .export:
            let game = try find(arguments[0], in: catalog)
            try GameStore.export(game, to: URL(fileURLWithPath: arguments[1]))
            print("exported \(game.name) to \(arguments[1])")
        case .remove:
            let game = try find(arguments[0], in: catalog)
            try GameStore.standard.remove(id: game.id)
            print("removed \(game.name); its mods and load orders stay in \(GraftPaths.standard(for: game).support.path)")
        case .check:
            let problems = catalog.problems + templates.problems + catalog.games.flatMap { game in
                GameDraft.editing(game).problems(in: catalog, macNativeGames: macNativeGames).map { "\(game.id): \($0)" }
            }
            for problem in problems { print(problem) }
            for game in catalog.games {
                if let template = templates.update(for: game) {
                    print("\(game.id): Graft has a newer template for \(game.name) (revision \(template.revision)). Review it in Graft with Game Info.")
                }
            }
            if macNativeGames == nil { print("No MacNativeGames folder is set, so scripts and folders weren't checked.") }
            guard problems.isEmpty else { exit(1) }
            print("No problems in \(counted(catalog.games.count, "game")).")
        case .templates:
            for template in templates.templates {
                let game = template.definition
                let added = catalog.game(id: game.id) != nil ? ", added" : ""
                print("  \(game.id.padding(toLength: 10, withPad: " ", startingAt: 0))\(game.name) (\(game.mods.kind.title)\(added))")
            }
            print("Your own templates go in \(GameTemplates.userFolder.path).")
        }
    }

    private func find(_ id: String, in catalog: GameCatalog) throws -> GameDefinition {
        guard let game = catalog.game(id: id) else {
            fail("unknown game '\(id)'; your games: \(catalog.games.map(\.id).joined(separator: ", "))")
        }
        return game
    }

    private func add(_ draft: GameDraft, app: String?, catalog: GameCatalog, root: URL) async throws {
        let game = draft.definition
        let problems = draft.fieldProblems(in: catalog)
        guard problems.isEmpty else {
            fail((["\(game.name.isEmpty ? "This game" : game.name) can't be added yet:"] + problems.map { "  \($0)" }
                  + ["Add it in Graft with Add Game, where you can fill in the rest."]).joined(separator: "\n"))
        }
        try GameStore.standard.save(game)
        try SettingsStore.select(game, root: root)
        let store = SettingsStore(paths: .standard(for: game), game: game)
        if let app {
            _ = try await store.using(gameApp: app)
        } else {
            _ = try await store.loadSavingDetected()
        }
        let source = switch draft.origin {
        case .template(let id): "from the \(id) template"
        case .detected: "from what Graft found in the app and in MacNativeGames"
        case .imported(let file): "from \(file)"
        case .existing: "again"
        }
        print("\(draft.isNew ? "added" : "replaced") \(game.name) (\(game.id)) \(source)")
    }
}

extension GameAction {
    static func listOrSwitch(to wanted: String?, root: URL) async throws {
        let catalog = GameCatalog.shared
        var selection = SettingsStore.selection(root: root, catalog: catalog)
        if let wanted = wanted?.lowercased() {
            guard let chosen = catalog.games.first(where: { $0.id == wanted || $0.name.lowercased() == wanted }) else {
                fail((catalog.problems.map { "problem: \($0)" } + ["unknown game '\(wanted)'; your games: \(catalog.games.map(\.id).joined(separator: ", "))"]).joined(separator: "\n"))
            }
            try SettingsStore.select(chosen, root: root)
            selection = .game(chosen)
        }
        for problem in catalog.problems { print("problem: \(problem)") }
        guard !catalog.games.isEmpty else {
            print(noGames)
            return
        }
        var current: GraftSettings?
        if case .game(let game) = selection {
            current = try await SettingsStore(paths: .standard(for: game), game: game).loadSavingDetected()
        }
        for entry in LibraryGame.all(current: current, catalog: catalog) {
            print("\(entry.id == current?.definition.id ? "*" : " ") \(entry.id)\t\(entry.game.name) (\(entry.status.lowercased()))")
        }
    }
}
