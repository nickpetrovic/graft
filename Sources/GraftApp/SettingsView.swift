import AppKit
import ModKit
import SwiftUI

struct SettingsView: View {
    let library: LibraryModel
    @ViewState private var searching = false

    var body: some View {
        let general = library.general
        let check = GeneralCheck(general)
        Form {
            Section {
                PathRow(title: "MacNativeGames folder", path: general.macNativeGames,
                        found: check.macNativeGames == nil, kind: .folder,
                        summary: "The MacNativeGames folder you downloaded.",
                        detail: "Graft uses its scripts to build game apps and to prepare your mods. It's the folder that contains build_app.py.") { path in
                    library.updateGeneral { $0.macNativeGames = path }
                }
                ForEach(library.catalog.problems + library.templates.problems, id: \.self) { notice in
                    Label(notice, systemImage: "info.circle")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("MacNativeGames")
            } footer: {
                Text("These settings apply to every game.")
                    .foregroundStyle(.secondary)
            }
            Section("Switch") {
                PathRow(title: "Keys folder", path: general.keysFolder,
                        found: check.keysFolder == nil, kind: .folder,
                        summary: "The folder with prod.keys from your own Switch.",
                        detail: "The keys let Graft read your game and update files. The same keys work for every game.") { path in
                    library.updateGeneral { $0.keysFolder = path }
                }
            }
            Section("Game Templates") {
                SettingRow(summary: "Templates fill in Add Game for the games they describe. Put your own templates, or ones shared with you, in this folder. A template with the same short name as one of Graft's replaces it.",
                           detail: "A template is a game definition file, like the ones Export Game saves.") {
                    Button("Show Templates Folder") { library.showTemplatesFolder() }
                }
            }
            Section("Crashes") {
                SettingRow(summary: "Lets Graft name the mod that caused a crash. The game writes a log to ~/Library/Logs/MacNativeGames.",
                           detail: "Without the log, Graft can only tell that the game stopped, not which mod's code was running.") {
                    Toggle("Keep a game log", isOn: Binding(
                        get: { general.keepGameLog },
                        set: { enabled in library.updateGeneral { $0.keepGameLog = enabled } }
                    ))
                }
            }
            if !check.problems.isEmpty {
                Section("Needs Attention") {
                    ForEach(check.problems, id: \.self) { problem in
                        Label(problem, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
            }
            Section {
                SettingRow(summary: "Searches your home folder again for the MacNativeGames folder and your keys.",
                           detail: "Paths you chose yourself are replaced by what the search finds.") {
                    Button(searching ? "Searching…" : "Find Files Again") {
                        searching = true
                        let baseGame = library.session?.settings.game.baseGame ?? ""
                        let gameFolder = baseGame.isEmpty ? nil : URL(fileURLWithPath: baseGame).deletingLastPathComponent()
                        Task {
                            let found = await Task.detached { SettingsDetector.detectGeneral(near: gameFolder) }.value
                            library.updateGeneral { settings in
                                if !found.macNativeGames.isEmpty { settings.macNativeGames = found.macNativeGames }
                                if !found.keysFolder.isEmpty { settings.keysFolder = found.keysFolder }
                            }
                            searching = false
                        }
                    }
                    .disabled(searching)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 600, height: WindowSizing.settingsHeight(on: NSScreen.main?.visibleFrame))
    }
}

struct SettingRow<Control: View>: View {
    let summary: String
    let detail: String
    @ViewBuilder let control: () -> Control

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            control()
            Text(summary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .help(detail)
    }
}
