import AppKit
import ModKit
import SwiftUI

struct LibrarySidebar: View {
    let library: LibraryModel
    @ViewState private var dropTargeted = false

    var body: some View {
        List(selection: Binding<String?>(
            get: { library.session?.game.id },
            set: { id in
                if let entry = library.games.first(where: { $0.id == id }) { library.select(entry.game) }
            }
        )) {
            Section("My Games") {
                ForEach(library.games) { entry in
                    LibraryRow(entry: entry)
                        .tag(entry.id)
                }
                if library.games.isEmpty {
                    Text("Drop a game app MacNativeGames built here, or choose Add Game.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .selectionDisabled()
                }
            }
            if !library.suggestions.isEmpty {
                Section("Found on This Mac") {
                    ForEach(library.suggestions) { suggestion in
                        SuggestionRow(suggestion: suggestion) { library.add(suggestion) }
                            .selectionDisabled()
                            .disabled(library.locksControls)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .contextMenu(forSelectionType: String.self) { ids in
            if let entry = library.games.first(where: { ids.contains($0.id) }) {
                menu(for: entry)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack(spacing: 8) {
                Button {
                    library.chooseGameToAdd()
                } label: {
                    Label("Add Game…", systemImage: "plus")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .disabled(library.locksControls)
                .help("Add a game app (.app) that MacNativeGames built.")
                InfoButton(title: "Adding a game") {
                    Text("Choose the game app (.app) that MacNativeGames built from your own copy of a game, for example Tears of the Kingdom.app. MacNativeGames puts it next to your game file unless you chose another folder when building.")
                    Text("Graft fills in how the game is set up from its template for that game, or from what it finds in the app and in the port's MacNativeGames folder. You check everything before the game is added, and you can edit it later.")
                    Text("An app for a game you already have is added as another version of it.")
                    Text("Found on This Mac lists game apps Graft has a template for, in your Games folder and the folders inside it, in ~/Applications and in /Applications.")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.bar)
            .overlay(alignment: .top) { Divider() }
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let app = urls.first(where: { $0.pathExtension == "app" }) else { return false }
            library.addGame(app.path)
            return true
        } isTargeted: { dropTargeted = $0 }
        .overlay {
            if dropTargeted {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.jade, style: StrokeStyle(lineWidth: 2, dash: [6]))
                    .padding(6)
            }
        }
    }

    @ViewBuilder
    private func menu(for entry: LibraryGame) -> some View {
        if let app = entry.app {
            Button("Show Game App in Finder") { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: app)]) }
        }
        if entry.isInstalled, let session = library.session {
            Button("Add Another Version…") { session.chooseOtherVersion(of: entry.game, startingAt: entry.app) }
                .disabled(library.locksControls)
        }
        Divider()
        Button("Edit Game…") { library.edit(entry.game) }
            .disabled(library.locksControls)
        Button("Export Game…") { library.export(entry.game) }
        Button("Show Definition in Finder") { library.revealDefinition(of: entry.game) }
        Divider()
        Button("Remove Game…") { library.removing = entry.game }
            .disabled(library.locksControls)
    }
}

struct LibraryRow: View {
    let entry: LibraryGame

    var body: some View {
        HStack(spacing: 10) {
            GameIcon(app: entry.app)
                .frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.game.name)
                    .lineLimit(1)
                Text(entry.status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

struct SuggestionRow: View {
    let suggestion: GameSuggestion
    let add: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            GameIcon(app: suggestion.app)
                .frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(suggestion.template.definition.name)
                    .lineLimit(1)
                Text(suggestion.version.map { "Version \($0)" } ?? "Not added yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer(minLength: 4)
            Button("Add…", action: add)
                .controlSize(.small)
        }
        .padding(.vertical, 2)
        .help(suggestion.app)
    }
}

struct GameIcon: View {
    let app: String?

    var body: some View {
        if let app {
            Image(nsImage: NSWorkspace.shared.icon(forFile: app))
                .resizable()
        } else {
            Image(systemName: "gamecontroller")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 26)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
    }
}
