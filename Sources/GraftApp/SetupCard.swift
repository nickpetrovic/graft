import ModKit
import SwiftUI

struct SetupCard: View {
    let model: AppModel
    let library: LibraryModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(model.game.unsupportedReason == nil ? "Finish setting up \(model.game.name)" : "\(model.game.name) isn't supported yet",
                  systemImage: model.game.unsupportedReason == nil ? "wrench.and.screwdriver" : "minus.circle")
                .font(.headline)
            ForEach([model.settingsError, model.engineProblem].compactMap { $0 }, id: \.self) { reason in
                Text(reason)
                    .foregroundStyle(.secondary)
            }
            ForEach(model.setup.files, id: \.file.role) { problem in
                row(title: problem.file.label, problem: problem.message, help: problem.file.detail) {
                    Button("Choose…") { choose(problem.file) }
                }
            }
            ForEach(model.setup.definition, id: \.self) { problem in
                row(title: "Game definition", problem: problem, help: "How \(model.game.name) is set up in Graft doesn't match your MacNativeGames folder or the game app.") {
                    Button("Edit Game…") { library.edit(model.game) }
                }
            }
            ForEach(model.setup.general, id: \.self) { problem in
                row(title: "General settings", problem: problem, help: "These settings apply to every game.") {
                    Button("Open Settings") { openSettings() }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func row<Action: View>(title: String, problem: String, help: String,
                                   @ViewBuilder action: () -> Action) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(problem)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            action()
        }
        .help(help)
    }

    private func choose(_ file: GameDefinition.FileSetting) {
        guard let path = FilePicker.choose(file.kind, startingAt: model.settings.game[file.role]) else { return }
        model.updateGame { $0[file.role] = path }
    }
}
