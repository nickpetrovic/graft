import AppKit
import ModKit
import SwiftUI

struct GameEditorSheet: View {
    enum Tab: String, CaseIterable, Identifiable {
        case game = "Game"
        case files = "Files"
        case mods = "Mods"
        case versions = "Versions"
        case recognition = "Recognition"

        var id: Self { self }
    }

    let library: LibraryModel
    @ViewState private var editor: GameEditor
    @ViewState private var tab = Tab.game
    @ViewState private var ports: [String] = []
    @ViewState private var showsProblems = false
    @Environment(\.dismiss) private var dismiss

    init(library: LibraryModel, editor: GameEditor) {
        self.library = library
        _editor = ViewState(initialValue: editor)
    }

    private var draft: GameDraft { editor.draft }
    private var game: GameDefinition { editor.draft.definition }

    var body: some View {
        let catalog = library.catalog
        let problems = draft.problems(in: catalog, macNativeGames: library.macNativeGames)
        VStack(spacing: 0) {
            header
            Picker("Section", selection: $tab) {
                ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
            Group {
                switch tab {
                case .game: GameTab(editor: $editor, ports: ports)
                case .files: FilesTab(editor: $editor)
                case .mods: ModsTab(editor: $editor)
                case .versions: VersionsTab(editor: $editor)
                case .recognition: RecognitionTab(editor: $editor)
                }
            }
            .formStyle(.grouped)
            footer(problems: problems, blocking: !draft.isComplete(in: catalog))
        }
        .frame(width: 640, height: 760)
        .task { ports = GameDraft.portFolders(in: library.macNativeGames) }
        .onChange(of: game.macNativeGamesFolder) { previous, folder in
            guard draft.isNew, draft.origin == .detected, let folder, !folder.isEmpty, folder != previous else { return }
            editor.draft = GameDraft.make(app: editor.app, portFolder: folder, macNativeGames: library.macNativeGames, templates: library.templates)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            if let app = editor.app {
                Image(nsImage: NSWorkspace.shared.icon(forFile: app))
                    .resizable()
                    .frame(width: 44, height: 44)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(draft.isNew ? "Add \(game.name.isEmpty ? "a Game" : game.name)" : "Edit \(game.name)")
                    .font(.title3.weight(.semibold))
                Text(origin)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
    }

    private var origin: String {
        switch draft.origin {
        case .template(let id) where draft.isNew:
            "Filled in from Graft's template for \(library.templates.template(id: id)?.definition.name ?? id). Check it, then add the game."
        case .template:
            "This is Graft's newer template for this game. Review the changes, then save to use them."
        case .detected:
            "Graft filled in what it found in the app and in MacNativeGames. Check the rest, then add the game."
        case .imported(let file):
            draft.isNew ? "Read from \(file). Check it, then add the game." : "Read from \(file). Saving replaces how \(game.name) is set up."
        case .existing:
            "Changes apply as soon as you save."
        }
    }

    private func footer(problems: [String], blocking: Bool) -> some View {
        HStack(spacing: 12) {
            if let first = problems.first {
                Button {
                    showsProblems = true
                } label: {
                    Label(problems.count == 1 ? first : "\(first) \(counted(problems.count - 1, "more problem")).", systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.orange)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showsProblems, arrowEdge: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(problems, id: \.self) { problem in
                            Label(problem, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(16)
                    .frame(width: 380)
                }
            } else {
                Label("Everything Graft can check is in place", systemImage: "checkmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(.green)
            }
            Spacer(minLength: 8)
            Button("Cancel", role: .cancel) { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button(draft.isNew ? "Add Game" : "Save") {
                if library.save(editor) { dismiss() }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(blocking)
        }
        .padding(20)
    }
}

private struct GameTab: View {
    @Binding var editor: GameEditor
    let ports: [String]

    private var game: GameDefinition { editor.draft.definition }
    private var id: String { game.id.isEmpty ? "game" : game.id }

    var body: some View {
        Form {
            Section("Game") {
                TextField("Name", text: $editor.draft.definition.name)
                TextField("Short name", text: $editor.draft.definition.id, prompt: Text("totk"))
                    .disabled(!editor.draft.isNew)
                    .help("Used by the command line and for Graft's folders. It can't change after the game is added.")
                CodeField("Title ID", text: $editor.draft.definition.titleId, prompt: "16 hexadecimal digits")
                    .help("The Nintendo title ID of the base game. Graft uses it to find the game's files.")
                CodeField("Update title ID", text: $editor.draft.definition.updateTitleId.orEmpty,
                          prompt: GameDraft.updateTitleId(for: game.titleId) ?? "16 hexadecimal digits")
                    .help("The title ID of the game's updates. Graft uses it to find update files.")
            }
            Section("MacNativeGames") {
                Picker("Port folder", selection: $editor.draft.definition.macNativeGamesFolder.orEmpty) {
                    Text("None").tag("")
                    ForEach(ports, id: \.self) { Text("games/\($0)").tag($0) }
                    if let folder = game.macNativeGamesFolder, !folder.isEmpty, !ports.contains(folder) {
                        Text("games/\(folder)").tag(folder)
                    }
                }
                TextField("Work folder name", text: $editor.draft.definition.workFolder.orEmpty, prompt: Text("\(id)_build"))
                    .help("The folder MacNativeGames builds the game in.")
                TextField("Game folder in the work folder", text: $editor.draft.definition.workTree.orEmpty, prompt: Text("None"))
                    .help("The folder inside the work folder that holds the extracted game. Leave it empty if the port has none.")
                TextField("Data folder name", text: $editor.draft.definition.dataFolder.orEmpty, prompt: Text(id))
                    .help("The game's folder in ~/Library/Application Support/MacNativeGames, which holds its mod folder.")
            }
            Section("App") {
                CodeField("App identifier", text: appBinding(\.bundleIdentifier), prompt: "org.macnativegames.\(id)")
                    .help("The bundle identifier MacNativeGames gives the game app. Graft finds and starts the game with it.")
                TextField("App file name", text: appBinding(\.fileName).orEmpty, prompt: Text("\(game.name.isEmpty ? "Game" : game.name).app"))
                    .help("The app's file name, when it isn't the game's name followed by .app.")
                CodeField("Work folder key", text: appBinding(\.workFolderKey).orEmpty, prompt: "None")
                    .help("The key in the game app's Info.plist that records its work folder, for ports that record it.")
            }
            Section("Log") {
                TextField("Log file", text: logBinding(\.file).orEmpty, prompt: Text(id))
                    .help("The game's log file in ~/Library/Logs/MacNativeGames, without .log.")
                CodeField("Line prefix", text: logBinding(\.linePrefix).orEmpty, prompt: "[\(id)]")
                    .help("The text at the start of the game's own lines in the log.")
                CodeField("Log setting", text: logBinding(\.enableVariable).orEmpty, prompt: "None")
                    .help("The game app setting that turns the log on. Graft sets it when Keep a game log is on.")
            }
        }
    }

    private func appBinding<Value>(_ field: WritableKeyPath<GameDefinition.App, Value>) -> Binding<Value> {
        Binding(
            get: { (editor.draft.definition.app ?? GameDefinition.App(bundleIdentifier: ""))[keyPath: field] },
            set: { value in
                var app = editor.draft.definition.app ?? GameDefinition.App(bundleIdentifier: "")
                app[keyPath: field] = value
                editor.draft.definition.app = app == GameDefinition.App(bundleIdentifier: "") ? nil : app
            })
    }

    private func logBinding(_ field: WritableKeyPath<GameDefinition.Log, String?>) -> Binding<String?> {
        Binding(
            get: { (editor.draft.definition.log ?? GameDefinition.Log())[keyPath: field] },
            set: { value in
                var log = editor.draft.definition.log ?? GameDefinition.Log()
                log[keyPath: field] = value.flatMap { $0.isEmpty ? nil : $0 }
                editor.draft.definition.log = log == GameDefinition.Log() ? nil : log
            })
    }
}

private struct FilesTab: View {
    @Binding var editor: GameEditor

    var body: some View {
        Form {
            Section {
                Text("The paths Game Info and the setup card ask for. Graft checks each one before Play.")
                    .foregroundStyle(.secondary)
            }
            ForEach(GameDefinition.FileSetting.Role.allCases) { role in
                Section {
                    Toggle("Needs the \(role.title.lowercased())", isOn: needs(role))
                    if editor.draft.definition.files.contains(where: { $0.role == role }) {
                        TextField("Label", text: field(\.label, of: role))
                        TextField("Summary", text: field(\.summary, of: role), axis: .vertical)
                            .lineLimit(2...4)
                        TextField("Explanation", text: field(\.detail, of: role), axis: .vertical)
                            .lineLimit(3...6)
                    }
                } header: {
                    Text(role.title)
                } footer: {
                    Text(role.purpose)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func field(_ text: WritableKeyPath<GameDefinition.FileSetting, String>, of role: GameDefinition.FileSetting.Role) -> Binding<String> {
        Binding(
            get: { editor.draft.definition.files.first { $0.role == role }?[keyPath: text] ?? "" },
            set: { value in
                guard let index = editor.draft.definition.files.firstIndex(where: { $0.role == role }) else { return }
                editor.draft.definition.files[index][keyPath: text] = value
            })
    }

    private func needs(_ role: GameDefinition.FileSetting.Role) -> Binding<Bool> {
        Binding(
            get: { editor.draft.definition.files.contains { $0.role == role } },
            set: { needed in
                var files = editor.draft.definition.files.filter { $0.role != role }
                if needed { files.append(GameDefinition.FileSetting(role: role)) }
                let order = GameDefinition.FileSetting.Role.allCases
                editor.draft.definition.files = files.sorted { order.firstIndex(of: $0.role)! < order.firstIndex(of: $1.role)! }
            })
    }
}

private extension GameDefinition.FileSetting.Role {
    var purpose: String {
        switch self {
        case .gameApp: "The Mac app MacNativeGames built. Play opens it."
        case .baseGame: "The base game file (XCI or NSP). Engines that combine mods with the game's own files read it."
        case .update: "The update file (NSP). Graft picks the one whose version matches the game app."
        case .workFolder: "The folder MacNativeGames built the game in. Graft uses its Python and its extracted files."
        }
    }
}

private struct ModsTab: View {
    @Binding var editor: GameEditor

    var body: some View {
        Form {
            Section {
                Picker("Mod support", selection: $editor.draft.modKind) {
                    ForEach(ModSupport.Kind.allCases) { Text($0.title).tag($0) }
                }
                Text(editor.draft.modKind.summary)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            switch editor.draft.definition.mods {
            case .tksharp:
                TkSharpSection(settings: Binding(
                    get: { editor.draft.definition.tkSharp ?? TkSharpSettings() },
                    set: { editor.draft.definition.mods = .tksharp($0) }))
            case .files:
                FileModsSection(settings: Binding(
                    get: { editor.draft.definition.fileMods ?? FileModSettings() },
                    set: { editor.draft.definition.mods = .files($0) }))
            case .unsupported(let reason):
                Section("Reason") {
                    TextField("Why mods aren't supported yet", text: Binding(
                        get: { reason ?? "" },
                        set: { editor.draft.definition.mods = .unsupported(reason: $0.isEmpty ? nil : $0) }), axis: .vertical)
                        .lineLimit(2...4)
                }
            }
        }
    }
}

private struct TkSharpSection: View {
    @Binding var settings: TkSharpSettings

    var body: some View {
        Section("MacNativeGames scripts") {
            CodeField("Rebuild script", text: $settings.buildScript, prompt: "build_app.py")
                .help("Rebuilds the game app, relative to the MacNativeGames folder.")
            CodeField("Manifest script", text: $settings.manifestScript, prompt: "games/name/scripts/make_mod_manifest.py")
                .help("Writes the mod folder's manifest, relative to the MacNativeGames folder.")
            CodeField("Patch sites script", text: $settings.patchSitesScript.orEmpty, prompt: "None")
                .help("Lists the places the game app patches itself, so code mods can be checked against them.")
        }
        Section {
            Toggle("Code mods", isOn: Binding(
                get: { settings.codeMods != nil },
                set: { settings.codeMods = $0 ? settings.codeMods ?? TkSharpSettings.CodeMods() : nil }))
            if settings.codeMods != nil {
                CodeField("Launch setting", text: codeBinding(\.launchVariable), prompt: "GAME_PCHTXT")
                    .help("The variable that passes the code-mod file to the game when it starts.")
                CodeField("Memory size table", text: codeBinding(\.heapTable).orEmpty, prompt: "None")
                    .help("The game file that sets memory sizes. When a mod changes it, Graft rebuilds the app.")
                CodeField("Memory size record", text: codeBinding(\.heapRecord).orEmpty, prompt: "None")
                    .help("Where the app records which version of the memory size table it was built with, inside the work folder.")
                CodeField("Build ID file", text: codeBinding(\.buildIdFile).orEmpty, prompt: "None")
                    .help("The file inside the app that lets it load code mods when it starts, without a rebuild.")
            }
        } header: {
            Text("Code mods")
        }
        Section {
            Toggle("Title-screen text", isOn: $settings.titleText)
                .help("Lets you set text that the title screen shows while mods are on.")
            ForEach(settings.languages.indices, id: \.self) { index in
                let language = language(at: index)
                HStack(alignment: .firstTextBaseline) {
                    TextField("Code", text: language.code, prompt: Text("USen"))
                        .labelsHidden()
                        .monospaced()
                        .frame(width: 70)
                    TextField("Name", text: language.name, prompt: Text("English (United States)"))
                        .labelsHidden()
                    ListField(values: Binding(
                        get: { language.wrappedValue.versions ?? [] },
                        set: { language.wrappedValue.versions = $0.isEmpty ? nil : $0 }), prompt: "All versions")
                        .frame(width: 120)
                        .help("The game versions that have this language, separated by commas. Leave it empty for every version.")
                    Button {
                        settings.languages.remove(at: index)
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("Remove this language")
                    .accessibilityLabel("Remove this language")
                }
            }
            Button("Add Language") { settings.languages.append(TkSharpSettings.Language(code: "", name: "")) }
        } header: {
            Text("Text")
        } footer: {
            Text("Mods that change text are merged into the language you choose in Game Info. Codes are the game's own, such as USen or JPja.")
                .foregroundStyle(.secondary)
        }
    }

    private func language(at index: Int) -> Binding<TkSharpSettings.Language> {
        Binding(
            get: { settings.languages.indices.contains(index) ? settings.languages[index] : TkSharpSettings.Language(code: "", name: "") },
            set: { if settings.languages.indices.contains(index) { settings.languages[index] = $0 } })
    }

    private func codeBinding<Value>(_ field: WritableKeyPath<TkSharpSettings.CodeMods, Value>) -> Binding<Value> {
        Binding(
            get: { (settings.codeMods ?? TkSharpSettings.CodeMods())[keyPath: field] },
            set: { value in
                var codeMods = settings.codeMods ?? TkSharpSettings.CodeMods()
                codeMods[keyPath: field] = value
                settings.codeMods = codeMods
            })
    }
}

private struct FileModsSection: View {
    @Binding var settings: FileModSettings

    var body: some View {
        Section("Mod folder") {
            CodeField("Folder for .pak files", text: $settings.pakFolder, prompt: "Game/Content/Paks/~mods")
                .help("Where mods that are only .pak files go inside the game's files.")
            CodeField("Manifest script", text: $settings.manifestScript, prompt: "games/name/scripts/make_mod_manifest.py")
                .help("The port's script that writes the mod folder's manifest, relative to the MacNativeGames folder.")
            CodeField("Python", text: $settings.python, prompt: FileModSettings.defaultPython)
                .help("The Python environment the port's build makes, relative to the work folder.")
            CodeField("Game files in the app", text: $settings.appGameFolder, prompt: FileModSettings.defaultAppGameFolder)
                .help("The folder inside the game app that holds the game's files.")
        }
    }
}

private struct VersionsTab: View {
    @Binding var editor: GameEditor

    private var folders: Binding<GameDefinition.VersionFolders> {
        Binding(
            get: { editor.draft.definition.versionFolders ?? GameDefinition.VersionFolders() },
            set: { editor.draft.definition.versionFolders = $0 == GameDefinition.VersionFolders() ? nil : $0 })
    }

    var body: some View {
        Form {
            Section {
                CodeField("Folder prefix", text: folders.prefix, prompt: "v")
                LabeledContent("Example", value: "1.2.1 → \(folders.wrappedValue.folder(forDisplayVersion: "1.2.1"))")
            } header: {
                Text("Version folders")
            } footer: {
                Text("Graft and MacNativeGames keep some files per game version, in folders named after the version: the prefix followed by the version's digits.")
                    .foregroundStyle(.secondary)
            }
            Section {
                PairList(pairs: folders.exceptions, keyPrompt: "1.0.0", valuePrompt: "v0")
            } header: {
                Text("Exceptions")
            } footer: {
                Text("Versions whose folder doesn't follow the rule.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct RecognitionTab: View {
    @Binding var editor: GameEditor

    private var signatures: Binding<GameDefinition.ModSignatures> {
        Binding(
            get: { editor.draft.definition.modSignatures ?? GameDefinition.ModSignatures() },
            set: { editor.draft.definition.modSignatures = $0.isEmpty ? nil : $0 })
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("File extensions") {
                    ListField(values: signatures.extensions, prompt: ".pak, .utoc")
                }
                LabeledContent("Folders") {
                    ListField(values: signatures.folders, prompt: "Game/Content/")
                }
            } header: {
                Text("Mods made for this game")
            } footer: {
                Text("When you add a mod to another game, Graft refuses it if it has these file extensions or folders, and says it is a \(editor.draft.definition.name.isEmpty ? "mod for this game" : "\(editor.draft.definition.name) mod"). Separate entries with commas.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct CodeField: View {
    let label: String
    @Binding var text: String
    let prompt: String

    init(_ label: String, text: Binding<String>, prompt: String) {
        self.label = label
        _text = text
        self.prompt = prompt
    }

    var body: some View {
        LabeledContent(label) {
            TextField(label, text: $text, prompt: Text(prompt))
                .labelsHidden()
                .multilineTextAlignment(.trailing)
                .monospaced()
        }
    }
}

private struct ListField: View {
    @Binding var values: [String]
    let prompt: String
    @ViewState private var text = ""

    var body: some View {
        TextField("", text: $text, prompt: Text(prompt))
            .labelsHidden()
            .multilineTextAlignment(.trailing)
            .monospaced()
            .onAppear { text = values.joined(separator: ", ") }
            .onChange(of: text) { _, text in
                values = Self.values(in: text)
            }
            .onChange(of: values) { _, values in
                if Self.values(in: text) != values { text = values.joined(separator: ", ") }
            }
    }

    private static func values(in text: String) -> [String] {
        text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
}

private struct PairList: View {
    struct Pair: Identifiable {
        let id = UUID()
        var key: String
        var value: String
    }

    @Binding var pairs: [String: String]
    let keyPrompt: String
    let valuePrompt: String
    @ViewState private var rows: [Pair] = []

    var body: some View {
        ForEach($rows) { $row in
            HStack {
                TextField("Version", text: $row.key, prompt: Text(keyPrompt))
                    .labelsHidden()
                    .monospaced()
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                TextField("Folder", text: $row.value, prompt: Text(valuePrompt))
                    .labelsHidden()
                    .monospaced()
                Button {
                    rows.removeAll { $0.id == row.id }
                } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.borderless)
                .help("Remove this exception")
                .accessibilityLabel("Remove this exception")
            }
        }
        ForEach(Self.repeatedKeys(in: rows), id: \.self) { key in
            Label("Two exceptions are for \(key). Only the last one is kept.", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
        Button("Add Exception") { rows.append(Pair(key: "", value: "")) }
            .onAppear(perform: showPairs)
            .onChange(of: rows.map { [$0.key, $0.value] }) { _, _ in
                pairs = Self.pairs(in: rows)
            }
            .onChange(of: pairs) { _, pairs in
                if Self.pairs(in: rows) != pairs { showPairs() }
            }
    }

    private func showPairs() {
        rows = pairs.sorted { $0.key < $1.key }.map { Pair(key: $0.key, value: $0.value) }
    }

    private static func pairs(in rows: [Pair]) -> [String: String] {
        Dictionary(rows.map { ($0.key, $0.value) }, uniquingKeysWith: { _, last in last })
    }

    private static func repeatedKeys(in rows: [Pair]) -> [String] {
        Dictionary(grouping: rows.map(\.key).filter { !$0.isEmpty }, by: { $0 }).filter { $0.value.count > 1 }.keys.sorted()
    }
}

extension Binding where Value == String? {
    var orEmpty: Binding<String> {
        Binding<String>(get: { wrappedValue ?? "" }, set: { wrappedValue = $0.isEmpty ? nil : $0 })
    }
}
