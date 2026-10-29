import Foundation

public struct GameDraft: Sendable, Equatable {
    public enum Origin: Sendable, Equatable {
        case template(String)
        case detected
        case imported(String)
        case existing
    }

    public var definition: GameDefinition {
        didSet { remember(oldValue.mods) }
    }

    public let origin: Origin
    public let originalId: String?
    private var setAside: [ModSupport.Kind: ModSupport] = [:]

    public init(definition: GameDefinition, origin: Origin, originalId: String? = nil) {
        self.definition = definition
        self.origin = origin
        self.originalId = originalId
    }

    public static func editing(_ game: GameDefinition) -> GameDraft {
        GameDraft(definition: game, origin: .existing, originalId: game.id)
    }

    public static func importing(_ game: GameDefinition, from file: URL, catalog: GameCatalog) -> GameDraft {
        GameDraft(definition: game, origin: .imported(file.lastPathComponent), originalId: catalog.game(id: game.id)?.id)
    }

    public static func applying(_ template: GameTemplate, to game: GameDefinition) -> GameDraft {
        var updated = template.game()
        updated.id = game.id
        return GameDraft(definition: updated, origin: .template(template.id), originalId: game.id)
    }

    public var isNew: Bool { originalId == nil }

    public var modKind: ModSupport.Kind {
        get { definition.mods.kind }
        set {
            guard newValue != definition.mods.kind else { return }
            definition.mods = setAside[newValue] ?? defaultMods(newValue)
            addRequiredFiles()
        }
    }

    private mutating func addRequiredFiles() {
        let roles = missingRoles
        let missing = Self.defaultFiles(for: definition).filter { roles.contains($0.role) }
        guard !missing.isEmpty else { return }
        let order = GameDefinition.FileSetting.Role.allCases
        definition.files = (definition.files + missing).sorted { order.firstIndex(of: $0.role)! < order.firstIndex(of: $1.role)! }
    }

    var missingRoles: [GameDefinition.FileSetting.Role] {
        let listed = Set(definition.files.map(\.role))
        return (definition.mods.engineSettings?.requiredFiles ?? []).filter { !listed.contains($0) }
    }

    private mutating func remember(_ previous: ModSupport) {
        guard previous.kind != definition.mods.kind else { return }
        setAside[previous.kind] = previous
    }

    private func defaultMods(_ kind: ModSupport.Kind) -> ModSupport {
        guard kind == .files, let port = definition.macNativeGamesFolder else { return .empty(kind) }
        return .files(FileModSettings(manifestScript: Self.manifestScript(forPort: port)))
    }

    public static func == (lhs: GameDraft, rhs: GameDraft) -> Bool {
        lhs.definition == rhs.definition && lhs.origin == rhs.origin && lhs.originalId == rhs.originalId
    }

    public static func make(app: String?, portFolder: String?, macNativeGames: URL?, templates: GameTemplates) -> GameDraft {
        let identifier = app.flatMap(AppBundle.bundleIdentifier(at:))
        let games = macNativeGames?.appending(path: "games")
        let port = portFolder ?? identifier.flatMap { identifier in games.flatMap { Self.portFolder(for: identifier, in: $0) } }
        if let template = identifier.flatMap(templates.template(bundleIdentifier:)) ?? port.flatMap(templates.template(portFolder:)) {
            return GameDraft(definition: template.game(), origin: .template(template.id))
        }
        return GameDraft(definition: detect(app: app, identifier: identifier, port: port, macNativeGames: macNativeGames), origin: .detected)
    }

    static func detect(app: String?, identifier: String?, port: String?, macNativeGames: URL?) -> GameDefinition {
        let info = app.flatMap(AppBundle.info(at:))
        var name = info?["CFBundleDisplayName"] as? String ?? info?["CFBundleName"] as? String ?? ""
        var bundleIdentifier = identifier ?? ""
        var game = GameDefinition(id: "", name: "", titleId: "")
        if let port, let folder = macNativeGames?.appending(path: "games/\(port)") {
            game.macNativeGamesFolder = port
            if name.isEmpty { name = readmeName(in: folder) ?? "" }
            if bundleIdentifier.isEmpty { bundleIdentifier = "org.macnativegames.\(port)" }
            game.titleId = titleId(in: folder) ?? ""
            game.dataFolder = dataFolder(in: folder)
            let workFolder = (try? FileManager.default.contentsOfDirectory(atPath: folder.path))?.sorted().first { $0.hasSuffix("_build") }
            game.workFolder = workFolder
            let manifest = Self.manifestScript(forPort: port)
            if let macNativeGames, FileManager.default.fileExists(atPath: macNativeGames.appending(path: manifest).path) {
                var files = FileModSettings(manifestScript: manifest)
                if let workFolder, FileManager.default.fileExists(atPath: folder.appending(path: "\(workFolder)/.venv").path) {
                    files.python = ".venv/bin/python"
                }
                game.mods = .files(files)
            }
        }
        game.name = name
        game.id = slug(port ?? bundleIdentifier.split(separator: ".").last.map(String.init) ?? name)
        game.app = bundleIdentifier.isEmpty ? nil : GameDefinition.App(bundleIdentifier: bundleIdentifier)
        game.updateTitleId = updateTitleId(for: game.titleId)
        if case .files(var files) = game.mods, let app {
            let appURL = URL(fileURLWithPath: app)
            if !FileManager.default.fileExists(atPath: appURL.appending(path: files.appGameFolder).path),
               FileManager.default.fileExists(atPath: appURL.appending(path: "Contents/Resources/\(game.id)").path) {
                files.appGameFolder = "Contents/Resources/\(game.id)"
                game.mods = .files(files)
            }
        }
        game.files = defaultFiles(for: game)
        return game
    }

    static func manifestScript(forPort port: String) -> String {
        "games/\(port)/scripts/make_mod_manifest.py"
    }

    static func defaultFiles(for game: GameDefinition) -> [GameDefinition.FileSetting] {
        let appName = game.appFileName ?? "the game app"
        var files = [
            GameDefinition.FileSetting(role: .gameApp, summary: "The Mac app MacNativeGames built for \(game.name).",
                                       detail: "Play opens this app. It's named \(appName), and MacNativeGames puts it next to your game file unless you chose another folder when building."),
        ]
        switch game.mods.kind {
        case .files:
            files.append(GameDefinition.FileSetting(role: .workFolder, summary: "The folder MacNativeGames worked in when it built the game app.",
                                                    detail: "It's named \(game.workFolderName) unless you chose another name when building. Graft uses the Python that the build set up there to prepare your mods for the game."))
        case .tksharp:
            files += [
                GameDefinition.FileSetting(role: .baseGame, summary: "Your copy of the game itself: the XCI or NSP file you dumped from your Switch.",
                                           detail: "Graft reads the game's original files from it, so it can combine your mods with them. Reading it needs the keys from your Switch, which you set in Settings."),
                GameDefinition.FileSetting(role: .update, summary: "Your copy of the game's update: the NSP file you dumped from your Switch.",
                                           detail: "Mods are combined with the game files of this exact version, so it has to match the game app's version."),
                GameDefinition.FileSetting(role: .workFolder, summary: "The folder MacNativeGames worked in when it built the game app.",
                                           detail: "It's named \(game.workFolderName) unless you chose another name when building."),
            ]
        case .unsupported:
            break
        }
        return files
    }

    public static func updateTitleId(for titleId: String) -> String? {
        let base = titleId.uppercased()
        guard isTitleId(base), base.hasSuffix("000") else { return nil }
        return String(base.dropLast(3)) + "800"
    }

    static func isTitleId(_ text: String) -> Bool {
        text.count == 16 && text.allSatisfy { $0.isASCII && $0.isHexDigit }
    }

    public func fieldProblems(in catalog: GameCatalog) -> [String] {
        let game = definition
        var problems: [String] = []
        if game.name.trimmingCharacters(in: .whitespaces).isEmpty { problems.append("Give the game a name.") }
        if game.id.isEmpty {
            problems.append("Give the game a short name.")
        } else if game.id != Self.slug(game.id) {
            problems.append("The short name can only use lowercase letters, digits and hyphens.")
        } else if originalId != game.id, catalog.game(id: game.id) != nil {
            problems.append("Another game already uses the short name \(game.id).")
        }
        if !Self.isTitleId(game.titleId) { problems.append("The title ID is 16 hexadecimal digits, for example 0100F2C0115B6000.") }
        if let update = game.updateTitleId, !update.isEmpty, !Self.isTitleId(update) {
            problems.append("The update's title ID is 16 hexadecimal digits, or leave it empty.")
        }
        if let identifier = game.bundleIdentifier, !identifier.isEmpty,
           let other = catalog.game(bundleIdentifier: identifier), other.id != originalId, other.id != game.id {
            problems.append("\(other.name) already uses the app identifier \(identifier).")
        }
        if game.unsupportedReason == nil, game.bundleIdentifier?.isEmpty ?? true {
            problems.append("Enter the app identifier, so Graft can find and start the game.")
        }
        let roles = game.files.map(\.role)
        if Set(roles).count != roles.count { problems.append("Each kind of file can only be listed once.") }
        for role in missingRoles {
            problems.append("\(game.mods.kind.title) needs the \(role.title.lowercased()). Turn it on in Files.")
        }
        if game.files.contains(where: { $0.label.trimmingCharacters(in: .whitespaces).isEmpty }) {
            problems.append("Every file needs a label.")
        }
        if let exceptions = game.versionFolders?.exceptions, exceptions.contains(where: { $0.key.isEmpty || $0.value.isEmpty }) {
            problems.append("Every version folder exception needs a version and a folder.")
        }
        problems += game.mods.engineSettings?.problems() ?? []
        return problems
    }

    public func problems(in catalog: GameCatalog, macNativeGames: URL?) -> [String] {
        fieldProblems(in: catalog) + GameCheck.problems(in: definition, macNativeGames: macNativeGames)
    }

    public func isComplete(in catalog: GameCatalog) -> Bool { fieldProblems(in: catalog).isEmpty }

    public static func portFolders(in macNativeGames: URL?) -> [String] {
        guard let games = macNativeGames?.appending(path: "games") else { return [] }
        return ((try? FileManager.default.contentsOfDirectory(atPath: games.path)) ?? [])
            .filter { !$0.hasPrefix(".") && isPortFolder(games.appending(path: $0)) }
            .sorted()
    }

    static func isPortFolder(_ folder: URL) -> Bool {
        ["README.md", "Makefile", "scripts"].contains { FileManager.default.fileExists(atPath: folder.appending(path: $0).path) }
    }

    static func readmeName(in port: URL) -> String? {
        guard let text = try? String(contentsOf: port.appending(path: "README.md"), encoding: .utf8),
              let heading = text.split(separator: "\n").first(where: { $0.hasPrefix("# ") }) else { return nil }
        let title = heading.dropFirst(2).split(separator: " — ").first.map(String.init) ?? String(heading.dropFirst(2))
        return title.trimmingCharacters(in: .whitespaces).nilIfEmpty
    }

    static func titleId(in port: URL) -> String? {
        let assets = port.appending(path: "assets")
        let files = ((try? FileManager.default.contentsOfDirectory(atPath: assets.path)) ?? []).filter { $0.hasSuffix(".json") }.sorted()
        for file in files {
            if let text = try? String(contentsOf: assets.appending(path: file), encoding: .utf8),
               let match = text.firstMatch(of: /"title_id"\s*:\s*"([0-9A-Fa-f]{16})"/) {
                return match.1.uppercased()
            }
        }
        guard let readme = try? String(contentsOf: port.appending(path: "README.md"), encoding: .utf8),
              let match = readme.firstMatch(of: /title ID `?([0-9A-Fa-f]{16})/) else { return nil }
        return match.1.uppercased()
    }

    static func dataFolder(in port: URL) -> String? {
        for file in sourceFiles(in: port) {
            if let text = try? String(contentsOf: file, encoding: .utf8),
               let match = text.firstMatch(of: /Application Support\/MacNativeGames\/([A-Za-z0-9_-]+)/) {
                return String(match.1)
            }
        }
        return nil
    }

    static func portFolder(for bundleIdentifier: String, in games: URL) -> String? {
        guard !bundleIdentifier.isEmpty else { return nil }
        if bundleIdentifier.hasPrefix("org.macnativegames."), let suffix = bundleIdentifier.split(separator: ".").last,
           FileManager.default.fileExists(atPath: games.appending(path: String(suffix)).path) {
            return String(suffix)
        }
        let folders = ((try? FileManager.default.contentsOfDirectory(atPath: games.path)) ?? []).filter { !$0.hasPrefix(".") }.sorted()
        return folders.first { folder in
            sourceFiles(in: games.appending(path: folder)).contains { file in
                (try? String(contentsOf: file, encoding: .utf8))?.contains(bundleIdentifier) == true
            }
        }
    }

    static func sourceFiles(in port: URL) -> [URL] {
        let fm = FileManager.default
        let top = ["Makefile"].map { port.appending(path: $0) }
        let nested = ["app", "scripts"].flatMap { folder in
            ((try? fm.contentsOfDirectory(atPath: port.appending(path: folder).path)) ?? []).sorted()
                .filter { ["m", "py", "plist", "h"].contains(URL(fileURLWithPath: $0).pathExtension) }
                .map { port.appending(path: "\(folder)/\($0)") }
        }
        return (top + nested).filter { fm.fileExists(atPath: $0.path) }
    }

    public static func slug(_ text: String) -> String {
        let lowered = text.lowercased().map { $0.isASCII && ($0.isLetter || $0.isNumber) ? $0 : "-" }
        return String(lowered).split(separator: "-").joined(separator: "-")
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
