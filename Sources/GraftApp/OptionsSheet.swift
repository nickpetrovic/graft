import ModKit
import SwiftUI

struct OptionsSheet: View {
    let model: AppModel
    let mod: InstalledMod
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(mod.displayName) options")
                .font(.title2.bold())
                .padding(20)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(Array(mod.optionGroups.enumerated()), id: \.offset) { index, group in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(group.name).font(.headline)
                            if !group.description.isEmpty {
                                Text(group.description).font(.callout).foregroundStyle(.secondary)
                            }
                            if group.allowsMultiple {
                                ForEach(group.options) { option in
                                    Toggle(isOn: Binding(
                                        get: { option.selected },
                                        set: { model.setOption(mod, group: index, option: option, selected: $0) }
                                    )) {
                                        OptionLabel(option: option)
                                    }
                                    .toggleStyle(.checkbox)
                                    .disabled(model.locksControls || (group.isRequired && option.selected && group.options.filter(\.selected).count == 1))
                                }
                            } else {
                                Picker("", selection: Binding<String>(
                                    get: { group.options.first(where: \.selected)?.id ?? "" },
                                    set: { newValue in
                                        if newValue.isEmpty, let current = group.options.first(where: \.selected) {
                                            model.setOption(mod, group: index, option: current, selected: false)
                                        } else if let option = group.options.first(where: { $0.id == newValue }) {
                                            model.setOption(mod, group: index, option: option, selected: true)
                                        }
                                    }
                                )) {
                                    if !group.isRequired {
                                        Text("None").tag("")
                                    }
                                    ForEach(group.options) { option in
                                        OptionLabel(option: option).tag(option.id)
                                    }
                                }
                                .pickerStyle(.radioGroup)
                                .labelsHidden()
                                .disabled(model.locksControls)
                            }
                        }
                    }
                }
                .padding(20)
            }
            Divider()
            HStack {
                Text("Changes apply when you press Play.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(minWidth: 520, minHeight: 480)
    }
}

struct OptionLabel: View {
    let option: ModOption

    var body: some View {
        VStack(alignment: .leading) {
            Text(option.name)
            if !option.description.isEmpty {
                Text(option.description).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
