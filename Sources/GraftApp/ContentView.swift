import AppKit
import ModKit
import SwiftUI

struct ContentView: View {
    @Bindable var library: LibraryModel

    var body: some View {
        NavigationSplitView(columnVisibility: Binding(
            get: { library.sidebarVisible ? .all : .detailOnly },
            set: { library.sidebarVisible = $0 != .detailOnly }
        )) {
            LibrarySidebar(library: library)
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
        } detail: {
            if let session = library.session {
                GameView(model: session, library: library)
            } else {
                WelcomeView(library: library)
            }
        }
        .sheet(item: $library.editor) { editor in
            GameEditorSheet(library: library, editor: editor)
        }
        .confirmationDialog(library.removing.map { "Remove \($0.name) from Graft?" } ?? "", isPresented: Binding(
            get: { library.removing != nil },
            set: { if !$0 { library.removing = nil } }
        ), presenting: library.removing) { game in
            Button("Remove \(game.name)", role: .destructive) { library.remove(game) }
        } message: { game in
            Text("Graft forgets how \(game.name) is set up. Its mods, load orders and settings stay in Graft's folder, so adding the game again brings them back.")
        }
        .task { await library.session?.load() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            library.refresh()
            Task { await library.session?.refreshQuietly() }
        }
    }
}
