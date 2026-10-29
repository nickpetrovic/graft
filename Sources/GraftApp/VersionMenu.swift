import ModKit
import SwiftUI

struct VersionMenu: View {
    let model: AppModel
    let current: GameVersion

    var body: some View {
        Menu {
            Picker("Version", selection: Binding(
                get: { model.settings.game.gameApp },
                set: { model.selectVersion($0) }
            )) {
                ForEach(model.versions) { version in
                    Text(version.title).tag(version.app)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
            Divider()
            Menu("Copy Load Order From") {
                ForEach(model.copyableVersions) { version in
                    Button(version.title) { model.copySetup(from: version) }
                }
            }
            .disabled(model.copyableVersions.isEmpty)
            Button("Add Another Version…") { model.chooseOtherVersion() }
        } label: {
            Text("Version \(current.title)")
                .monospacedDigit()
        }
        .menuStyle(.button)
        .fixedSize()
        .disabled(model.locksControls)
        .help("Each version of \(model.game.name) keeps its own load order. Play starts the version shown here.")
        .accessibilityLabel("Version \(current.title)")
    }
}
