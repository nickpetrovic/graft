import AppKit
import ModKit
import SwiftUI

struct WelcomeView: View {
    let library: LibraryModel
    @ViewState private var dropTargeted = false

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                if let error = library.errorMessage {
                    Banner(color: .red, systemImage: "xmark.octagon", text: error) {
                        Button("Dismiss") { library.errorMessage = nil }
                    }
                }
                ForEach(library.catalog.problems, id: \.self) { problem in
                    Banner(color: .orange, systemImage: "exclamationmark.triangle", text: problem) {
                        Button("Show in Finder") { library.revealGamesFolder() }
                    }
                }
                VStack(spacing: 12) {
                    Image(systemName: "gamecontroller")
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)
                    Text("Add your first game")
                        .font(.title2.weight(.semibold))
                    Text("Choose a game app that MacNativeGames built, or drop it here. Graft fills in how the game is set up from its templates, or from what it finds in the app and in MacNativeGames, and you check the rest.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 460)
                    HStack(spacing: 12) {
                        Button("Add Game…") { library.chooseGameToAdd() }
                            .buttonStyle(.glassProminent)
                        Button("Import Game…") { library.importGame() }
                    }
                    .controlSize(.large)
                }
                if !library.suggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Found on This Mac")
                            .font(.headline)
                        ForEach(library.suggestions) { suggestion in
                            SuggestionCard(suggestion: suggestion) { library.add(suggestion) }
                        }
                    }
                    .frame(maxWidth: 520)
                }
            }
            .padding(GameView.margin)
            .padding(.top, 40)
            .frame(maxWidth: .infinity)
        }
        .frame(minWidth: 480, minHeight: 480)
        .navigationTitle("Graft")
        .overlay {
            if dropTargeted {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.jade, style: StrokeStyle(lineWidth: 3, dash: [8]))
                    .padding(10)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let app = urls.first(where: { $0.pathExtension == "app" }) else { return false }
            library.addGame(app.path)
            return true
        } isTargeted: { dropTargeted = $0 }
    }
}

struct SuggestionCard: View {
    let suggestion: GameSuggestion
    let add: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            GameIcon(app: suggestion.app)
                .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(suggestion.template.definition.name)
                    .font(.body.weight(.medium))
                Text(suggestion.version.map { "Version \($0) · \(suggestion.template.definition.mods.kind.title)" } ?? suggestion.template.definition.mods.kind.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button("Add…", action: add)
        }
        .padding(12)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .help(suggestion.app)
    }
}
