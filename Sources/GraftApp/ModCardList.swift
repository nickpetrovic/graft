import ModKit
import SwiftUI

struct ModCardList<Header: View>: View {
    let model: AppModel
    let margin: CGFloat
    @ViewBuilder let header: () -> Header

    var body: some View {
        ReorderableCards(items: model.mods, isLocked: model.locksControls, margin: margin, header: header) { mod, position in
            ModRow(model: model, mod: mod, position: position)
                .accessibilityAction(named: "Move Up") { model.move(mod, to: position - 1) }
                .accessibilityAction(named: "Move Down") { model.move(mod, to: position + 1) }
        } move: { id, position in
            if let mod = model.mods.first(where: { $0.id == id }) { model.move(mod, to: position) }
        }
    }
}
