import ModKit
import SwiftUI

struct ModRow: View {
    let model: AppModel
    let mod: InstalledMod
    let position: Int
    @ViewState private var showingInfo = false
    @ViewState private var confirmingRemove = false
    @ViewState private var hovering = false

    var body: some View {
        HStack(spacing: 16) {
            Text("\(position + 1)")
                .font(.title3.monospacedDigit().weight(.medium))
                .foregroundStyle(.tertiary)
                .frame(minWidth: 22, alignment: .trailing)
                .contentTransition(.numericText())
                .accessibilityLabel("Position \(position + 1)")
            VStack(alignment: .leading, spacing: 4) {
                ModTitle(name: mod.displayName, badges: model.badges(for: mod))
                Text(summary)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .help(model.summaryHelp(for: mod))
            }
            .opacity(mod.enabled ? 1 : 0.45)
            Spacer(minLength: 16)
            if !mod.description.isEmpty {
                Button { showingInfo.toggle() } label: {
                    Image(systemName: "info.circle")
                        .font(.title3)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("About this mod")
                .popover(isPresented: $showingInfo, arrowEdge: .leading) {
                    ScrollView {
                        Text(mod.description)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                    }
                    .frame(width: 380)
                    .frame(maxHeight: 320)
                }
            }
            if mod.hasOptions {
                Button("Options…") { model.optionsMod = mod }
                    .disabled(model.locksControls)
            }
            Toggle(mod.displayName, isOn: Binding(get: { mod.enabled }, set: { model.setEnabled(mod, $0) }))
                .toggleStyle(.switch)
                .labelsHidden()
                .disabled(model.locksControls)
                .help(mod.enabled ? "Turn off \(mod.displayName)" : "Turn on \(mod.displayName)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.primary.opacity(hovering ? 0.08 : 0.045))
        )
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
        .contextMenu {
            if mod.hasOptions {
                Button("Options…") { model.optionsMod = mod }
            }
            Button(mod.enabled ? "Turn Off" : "Turn On") { model.setEnabled(mod, !mod.enabled) }
            Divider()
            Button("Move to Top") { withAnimation(.spring(duration: 0.35, bounce: 0.18)) { model.move(mod, to: 0) } }
                .disabled(position == 0)
            Button("Move to Bottom") { withAnimation(.spring(duration: 0.35, bounce: 0.18)) { model.move(mod, to: model.mods.count - 1) } }
                .disabled(position == model.mods.count - 1)
            if !model.versionTargets.isEmpty {
                Divider()
                Menu("Move to Version") {
                    ForEach(model.versionTargets) { version in
                        Button(version.title) { model.copy(mod, to: version, moving: true) }
                    }
                }
                Menu("Copy to Version") {
                    ForEach(model.versionTargets) { version in
                        Button(version.title) { model.copy(mod, to: version, moving: false) }
                            .disabled(model.version(version, has: mod))
                    }
                }
            }
            Divider()
            Button(model.currentVersionTitle.map { "Remove from \($0)…" } ?? "Remove…", role: .destructive) { confirmingRemove = true }
        }
        .disabled(model.locksControls)
        .confirmationDialog(model.currentVersionTitle.map { "Remove \(mod.displayName) from \($0)?" } ?? "Remove \(mod.displayName)?", isPresented: $confirmingRemove) {
            Button("Remove", role: .destructive) { model.remove(mod) }
        } message: {
            let others = model.otherVersions(using: mod)
            Text(others.isEmpty ? "No other version uses it, so it is deleted from Graft's library. To use it again, add its file again."
                 : "It stays in \(others.formatted(.list(type: .and))).")
        }
    }

    private var summary: String {
        let line = mod.summaryLine(buildId: model.layout?.buildId)
        return line.isEmpty ? "No changes for this game version" : line
    }
}

struct ModTitle: View {
    let name: String
    let badges: [ModBadge]

    var body: some View {
        ZStack(alignment: .leading) {
            BadgeCapsule(systemImage: "circle", title: "Badge", color: .clear)
                .hidden()
            HStack(spacing: 10) {
                Text(name)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                ForEach(badges) { badge in
                    BadgeLabel(badge: badge)
                }
            }
        }
    }
}
