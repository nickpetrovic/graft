import AppKit
import ModKit
import SwiftUI

struct GameInspector: View {
    let model: AppModel
    let library: LibraryModel

    var body: some View {
        GameInspectorForm(model: model, library: library)
            .id(model.game.id)
    }
}

private struct GameInspectorForm: View {
    let model: AppModel
    let library: LibraryModel
    @ViewState private var searching = false
    @ViewState private var titleText: String
    private let gameId: String

    init(model: AppModel, library: LibraryModel) {
        self.model = model
        self.library = library
        gameId = model.game.id
        _titleText = ViewState(initialValue: model.settings.game.titleText)
    }

    private var game: GameDefinition { model.game }
    private var entry: LibraryGame? { library.games.first { $0.id == game.id } }
    private var status: GameStatus { GameStatus(problems: model.setupProblems, supported: game.unsupportedReason == nil) }

    var body: some View {
        Form {
            header
            if let reason = game.unsupportedReason {
                Section {
                    Text(reason)
                        .foregroundStyle(.secondary)
                }
            } else {
                versions
                attention
                files
                mods
            }
            definition
        }
        .formStyle(.grouped)
        .onChange(of: model.settings.game.titleText) { _, saved in titleText = saved }
        .task(id: titleText) {
            guard titleText != model.settings.game.titleText else { return }
            do {
                try await Task.sleep(for: .milliseconds(500))
            } catch {
                return
            }
            saveTitleText()
        }
        .onDisappear(perform: saveTitleText)
    }

    private var header: some View {
        Section {
            HStack(spacing: 12) {
                if let app = entry?.app {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: app))
                        .resizable()
                        .frame(width: 48, height: 48)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(game.name)
                        .font(.headline)
                    Label(status.title, systemImage: status.symbol)
                        .font(.callout)
                        .foregroundStyle(status.color)
                }
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private var versions: some View {
        if !model.versions.isEmpty {
            Section {
                ForEach(model.versions) { version in
                    let current = version.app == model.settings.game.gameApp
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(version.title)
                                    .monospacedDigit()
                                if current {
                                    Text("Current")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(Color.jade)
                                }
                            }
                            Text(GameVersion.name(of: version.app))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .help(version.app)
                            Text(updateText(for: version, current: current))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .help(updateHelp(for: version, current: current))
                        }
                        Spacer(minLength: 8)
                        Button {
                            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: version.app)])
                        } label: {
                            Image(systemName: "magnifyingglass")
                        }
                        .buttonStyle(.borderless)
                        .help("Show \(GameVersion.name(of: version.app)) in Finder")
                        .accessibilityLabel("Show \(GameVersion.name(of: version.app)) in Finder")
                    }
                }
                HStack {
                    Button("Add Another Version…") { model.chooseOtherVersion() }
                        .disabled(model.locksControls)
                    Spacer()
                    InfoButton(title: "Adding another version") {
                        Text("Choose the game app (.app) that MacNativeGames built for another version of \(game.name). Graft finds game apps by itself next to your game files, in your Games folder and the folders inside it (for example ~/Games/macOS), in ~/Applications and in /Applications, so use this for an app saved somewhere else.")
                        Text("To get an app for another version, build \(game.name) in MacNativeGames with that version's update file. Keep the new app under a different name or in another folder, so it doesn't replace the one you have.")
                        Text("You don't need to choose an update file: when you switch to a version, Graft uses the update file in your Games folder whose version matches the app.")
                        Text("To switch versions, use the Version button next to Load Order. Each version keeps its own load order.")
                    }
                }
            } header: {
                Text("Versions")
            }
        }
    }

    private func update(for version: GameVersion, current: Bool) -> String {
        current ? model.settings.game.update : model.settings.game.otherApps.first { $0.gameApp == version.app }?.update ?? ""
    }

    private func updateText(for version: GameVersion, current: Bool) -> String {
        let update = update(for: version, current: current)
        return update.isEmpty ? "Update found when you switch to it" : "Update: \(GameVersion.name(of: update))"
    }

    private func updateHelp(for version: GameVersion, current: Bool) -> String {
        let update = update(for: version, current: current)
        return update.isEmpty ? "Graft picks the update file whose version matches this app when you switch to it." : update
    }

    @ViewBuilder
    private var attention: some View {
        if !model.setup.files.isEmpty || !model.setup.definition.isEmpty {
            Section("Needs Attention") {
                ForEach(model.setup.files, id: \.file.role) { problem in
                    pathRow(problem.file, problem: problem.message)
                }
                ForEach(model.setup.definition, id: \.self) { problem in
                    Label(problem, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private var files: some View {
        Section("Files") {
            ForEach(game.files.filter { model.setup.problem(for: $0.role) == nil && !($0.role == .gameApp && !model.versions.isEmpty) }) { file in
                pathRow(file)
            }
            Button(searching ? "Searching…" : "Find Files Again") {
                searching = true
                let game = game
                Task {
                    let found = await SettingsDetector(game: game, includeProtectedFolders: true).detect()
                    searching = false
                    guard model.game == game else { return }
                    model.updateGame { settings in
                        for file in game.files where !found.game[file.role].isEmpty {
                            settings[file.role] = found.game[file.role]
                        }
                    }
                }
            }
            .disabled(searching || model.locksControls)
            .help("Searches your Games, Downloads and Documents folders for this game's files. Paths you chose yourself are replaced by what the search finds.")
        }
    }

    @ViewBuilder
    private var mods: some View {
        let languages = game.languages(inVersion: model.layout?.displayVersion)
        if !languages.isEmpty || game.supportsTitleText {
            Section("Mods") {
                if !languages.isEmpty {
                    Picker("Text language", selection: Binding(
                        get: { model.settings.game.language },
                        set: { language in model.updateGame { $0.language = language } }
                    )) {
                        Text("Automatic (\(name(of: GameLanguage.resolve("auto", for: model.settings), in: languages)))").tag("auto")
                        Divider()
                        ForEach(languages, id: \.code) { language in
                            Text(language.name).tag(language.code)
                        }
                    }
                    .help("Mods that change text, such as item names or dialogue, are merged into this language's text. Automatic uses the language the game app runs in.")
                }
                if game.supportsTitleText {
                    TextField("Title screen", text: $titleText, prompt: Text("Normal title screen"))
                        .onSubmit(saveTitleText)
                        .help("Shown on the title screen while mods are on. Leave it empty to keep the normal title screen.")
                }
            }
        }
    }

    @ViewBuilder
    private var definition: some View {
        Section {
            if let template = model.templateUpdate {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Graft has a newer template for \(game.name).", systemImage: "arrow.down.circle")
                        .foregroundStyle(Color.jade)
                    HStack {
                        Button("Review…") { library.reviewTemplate(for: game) }
                        Button("Keep Mine") { library.dismissTemplate(for: game) }
                    }
                    .disabled(model.locksControls)
                }
                .help("Revision \(template.revision) of the template. Review shows it in the editor before anything changes.")
            }
            LabeledContent("Started from", value: source)
            ForEach(model.definitionProblems, id: \.self) { problem in
                Label(problem, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
            HStack {
                Button("Edit…") { library.edit(game) }
                    .disabled(model.locksControls)
                Button("Export…") { library.export(game) }
                Spacer()
                Button("Show in Finder") { library.revealDefinition(of: game) }
            }
        } header: {
            Text("Definition")
        } footer: {
            Text("How Graft finds this game's files and combines its mods. Graft keeps it in ~/Library/Application Support/Graft/games/\(game.id)/game.json.")
                .foregroundStyle(.secondary)
        }
    }

    private var source: String {
        guard let reference = game.template else { return "Your own settings" }
        let name = library.templates.template(id: reference.id)?.definition.name ?? reference.id
        return "\(name) template, revision \(reference.revision)"
    }

    private func pathRow(_ file: GameDefinition.FileSetting, problem: String? = nil) -> some View {
        PathRow(title: file.label, path: model.settings.game[file.role], found: model.setup.problem(for: file.role) == nil,
                kind: file.kind, summary: file.summary, detail: file.detail, problem: problem) { path in
            model.updateGame { $0[file.role] = path }
        }
    }

    private func name(of code: String, in languages: [TkSharpSettings.Language]) -> String {
        languages.first { $0.code == code }?.name ?? code
    }

    private func saveTitleText() {
        guard model.game.id == gameId else { return }
        let text = titleText
        model.updateGame { $0.titleText = text }
    }
}

struct GameStatus {
    let problems: [String]
    let supported: Bool

    var title: String {
        if !supported { return "Not supported yet" }
        if problems.isEmpty { return "Ready" }
        return "\(counted(problems.count, "thing")) to fix"
    }

    var symbol: String {
        if !supported { return "minus.circle" }
        return problems.isEmpty ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
    }

    var color: Color {
        if !supported { return .secondary }
        return problems.isEmpty ? .green : .orange
    }
}
