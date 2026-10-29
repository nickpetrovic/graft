import AppKit
import ModKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var library: LibraryModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate()
    }

    func applicationWillTerminate(_ notification: Notification) {
        ChildProcesses.shared.terminateAll()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let model = library?.session, case .working(let task) = model.activity else { return .terminateNow }
        let alert = NSAlert()
        alert.messageText = "Graft is still working"
        alert.informativeText = "\(task). If you quit now, this stops, and a rebuild of the game app starts over next time."
        alert.addButton(withTitle: "Keep Working")
        alert.addButton(withTitle: "Quit Anyway")
        return alert.runModal() == .alertSecondButtonReturn ? .terminateNow : .terminateCancel
    }
}
