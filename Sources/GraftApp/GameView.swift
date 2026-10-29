import AppKit
import ModKit
import SwiftUI
import UniformTypeIdentifiers

struct GameView: View {
    @Bindable var model: AppModel
    let library: LibraryModel
    @ViewState private var choosingFiles = false
    @ViewState private var dropTargeted = false

    static let margin: CGFloat = 20

    var body: some View {
        ZStack {
            content
        }
        .frame(minWidth: 480, minHeight: 480)
        .navigationTitle(model.game.name)
        .navigationSubtitle(subtitle)
        .toolbar { toolbar }
        .inspector(isPresented: $model.showsInspector) {
            GameInspector(model: model, library: library)
                .inspectorColumnWidth(min: 280, ideal: 320, max: 420)
        }
        .fileImporter(isPresented: $choosingFiles, allowedContentTypes: [.item, .folder], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result { model.add(urls) }
        }
        .sheet(item: $model.optionsMod) { mod in
            OptionsSheet(model: model, mod: mod)
        }
        .overlay {
            if dropTargeted {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.jade, style: StrokeStyle(lineWidth: 3, dash: [8]))
                    .padding(10)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in model.add(urls) }
        .onDropSessionUpdated { session in
            switch session.phase {
            case .entering, .active:
                if session.localSession == nil, !dropTargeted { dropTargeted = true }
            default:
                if dropTargeted { dropTargeted = false }
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            ProgressView()
                .controlSize(.small)
                .opacity(model.shownActivity == .idle ? 0 : 1)
                .accessibilityHidden(model.shownActivity == .idle)
        }
        .sharedBackgroundVisibility(.hidden)
        ToolbarItemGroup(placement: .primaryAction) {
            Button { choosingFiles = true } label: { Label("Add Mods", systemImage: "plus") }
                .help("Choose mods to add: \(model.modFormats)")
                .disabled(model.locksControls)
            Button { model.showsInspector.toggle() } label: { Label("Game Info", systemImage: "info.circle") }
                .help("Show or hide this game's versions, files and checks (⌘J)")
        }
        ToolbarSpacer(.fixed, placement: .primaryAction)
        ToolbarItem(placement: .primaryAction) {
            Button {
                model.play()
            } label: {
                Label(model.gameRunning ? "Show Game" : "Play",
                      systemImage: model.gameRunning ? "macwindow" : "play.fill")
                    .labelStyle(.titleAndIcon)
                    .padding(.horizontal, 6)
            }
            .buttonStyle(.glassProminent)
            .disabled(model.locksControls || !model.setupProblems.isEmpty)
            .help(model.needsApply ? "Applies your mod changes, then starts the game" : "Starts the game with your mods")
            .keyboardShortcut("p", modifiers: .command)
        }
    }

    private var subtitle: String {
        if let message = model.shownActivity.message { return message }
        guard let version = model.versions.first(where: { $0.app == model.settings.game.gameApp }) else { return status }
        return "Version \(version.title) · \(status)"
    }

    private var status: String {
        if !model.modsLoaded { return "Loading mods" }
        if model.mods.isEmpty { return "No mods yet" }
        if model.needsApply { return "Changes apply when you press Play" }
        if model.enabledCount < model.mods.count { return "\(model.enabledCount) of \(counted(model.mods.count, "mod")) on" }
        return model.mods.count == 1 ? "1 mod on" : "All \(model.mods.count) mods on"
    }

    @ViewBuilder
    private var content: some View {
        if model.mods.isEmpty {
            VStack(spacing: 16) {
                banners
                Spacer()
                if model.modsLoaded, model.game.unsupportedReason == nil {
                    emptyState
                }
                Spacer()
            }
            .padding(Self.margin)
        } else {
            modList
        }
    }

    private var modList: some View {
        ModCardList(model: model, margin: Self.margin) {
            banners
            loadOrderHeader
        }
        .scrollEdgeEffectStyle(.hard, for: .top)
    }

    private var loadOrderHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("Load Order")
                .font(.title3.weight(.semibold))
            if let current = model.versions.first(where: { $0.app == model.settings.game.gameApp }) {
                VersionMenu(model: model, current: current)
            }
            Spacer()
            Text("Higher in the list wins when two mods change the same thing")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "shippingbox")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("Add your first mod")
                .font(.title2.weight(.semibold))
            Text("Drag a mod here, or choose one. Graft adds \(model.modFormats).")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 440)
            Button("Add Mods…") { choosingFiles = true }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .disabled(model.locksControls)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var banners: some View {
        if hasBanners {
            VStack(spacing: 8) {
                if !model.setupProblems.isEmpty {
                    SetupCard(model: model, library: library)
                }
                if let importable = model.importable {
                    Banner(color: .blue, systemImage: "square.and.arrow.down", text: "Found a \(importable.manager) mod library at \(importable.location.deletingLastPathComponent().path). Import its mods, order and options?") {
                        Button("Import") { model.importLibrary() }
                        Button("Dismiss") { model.dismissImport() }
                    }
                }
                if let crash = model.crash {
                    Banner(color: .red, systemImage: "exclamationmark.triangle", text: crash.detail) {
                        if let name = crash.modName {
                            Button("Turn Off \(name) and Play") { model.disableCrashedModAndPlay() }
                        }
                        Button("Show Log") { model.openLog() }
                        Button("Dismiss") { model.crash = nil }
                    }
                }
                if let error = model.errorMessage {
                    Banner(color: .red, systemImage: "xmark.octagon", text: error) {
                        Button("Dismiss") { model.errorMessage = nil }
                    }
                }
                if let notice = model.notice {
                    Banner(color: .green, systemImage: "checkmark.circle", text: notice) {
                        Button("Dismiss") { model.notice = nil }
                    }
                }
            }
            .padding(.bottom, 8)
        }
    }

    private var hasBanners: Bool {
        !model.setupProblems.isEmpty || model.importable != nil || model.crash != nil
            || model.errorMessage != nil || model.notice != nil
    }
}
