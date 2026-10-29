import ModKit
import SwiftUI

@main
struct Graft: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ViewState private var library = LibraryModel()

    init() {
        #if DEBUG
        Snapshot.scheduleIfRequested(library: library)
        #endif
    }

    var body: some Scene {
        Window("Graft", id: "library") {
            ContentView(library: library)
                .tint(.jade)
                .onAppear { appDelegate.library = library }
        }
        .defaultWindowPlacement { _, context in
            WindowPlacement(size: WindowSizing.mainWindow(on: context.defaultDisplay.visibleRect))
        }
        .commands {
            CommandGroup(replacing: .sidebar) {
                Button(library.sidebarVisible ? "Hide Sidebar" : "Show Sidebar") { withAnimation { library.sidebarVisible.toggle() } }
                    .keyboardShortcut("b", modifiers: .command)
                Button(library.session?.showsInspector == true ? "Hide Game Info" : "Show Game Info") {
                    withAnimation { library.session?.showsInspector.toggle() }
                }
                .keyboardShortcut("j", modifiers: .command)
                .disabled(library.session == nil)
            }
            CommandGroup(after: .newItem) {
                Button("Add Game…") { library.chooseGameToAdd() }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                    .disabled(library.isWorking)
                Button("Import Game…") { library.importGame() }
                    .disabled(library.isWorking)
                Button("Export Game…") {
                    if let game = library.session?.game { library.export(game) }
                }
                .disabled(library.session == nil)
                Divider()
                Button("Import Load Order…") { library.session?.importSetup() }
                    .disabled(library.session.map { $0.isWorking || !$0.modsLoaded } ?? true)
                Button("Export Load Order…") { library.session?.exportSetup() }
                    .disabled(!(library.session?.modsLoaded ?? false))
                Divider()
                Button("Apply Mod Changes") {
                    Task { _ = await library.session?.apply(force: false) }
                }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(library.session.map { $0.isWorking || !$0.setupProblems.isEmpty } ?? true)
                Button("Rebuild Game App") {
                    Task { _ = await library.session?.apply(force: true) }
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(library.session.map { $0.isWorking || !$0.setupProblems.isEmpty } ?? true)
            }
        }

        Settings {
            SettingsView(library: library)
        }
    }
}
