#if DEBUG
import AppKit
import SwiftUI

@MainActor
enum Snapshot {
    static func value(after flag: String) -> String? {
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }

    static var target: URL? { value(after: "--snapshot").map { URL(fileURLWithPath: $0) } }

    static var size: NSSize? {
        let parts = value(after: "--snapshot-size")?.split(separator: "x").compactMap { Double($0) } ?? []
        return parts.count == 2 ? NSSize(width: parts[0], height: parts[1]) : nil
    }

    static var showsSettings: Bool { CommandLine.arguments.contains("--snapshot-settings") }

    static func scheduleIfRequested(library: LibraryModel) {
        guard let target else { return }
        if CommandLine.arguments.contains("--snapshot-inspector") {
            library.session?.showsInspector = true
        }
        Task {
            if CommandLine.arguments.contains("--snapshot-light") {
                NSApp.appearance = NSAppearance(named: .aqua)
            }
            while let model = library.session, !model.hasLoaded || model.isWorking {
                await pause(.milliseconds(200))
            }
            NSApp.activate()
            let window = NSApp.windows.first { $0.isVisible }
            if let size {
                window?.setFrameAutosaveName("")
                window?.setContentSize(size)
            }
            window?.makeKeyAndOrderFront(nil)

            if let app = value(after: "--snapshot-add") {
                library.addGame(app)
                await pause(.seconds(1))
                capture(window?.attachedSheet ?? window, to: target)
            } else if showsSettings {
                let hosting = NSHostingView(rootView: SettingsView(library: library))
                let settings = NSWindow(contentRect: NSRect(origin: .zero, size: hosting.fittingSize),
                                        styleMask: [.titled], backing: .buffered, defer: false)
                settings.title = "Settings"
                settings.contentView = hosting
                settings.orderFront(nil)
                await pause(.seconds(1))
                capture(settings, to: target)
            } else if let name = value(after: "--snapshot-options"), let model = library.session, let mod = model.mods.first(where: { $0.name == name }) {
                model.optionsMod = mod
                await pause(.seconds(1))
                capture(window?.attachedSheet ?? window, to: target)
            } else {
                await pause(.milliseconds(500))
                capture(window, to: target)
            }
            exit(0)
        }
    }

    static func pause(_ duration: Duration) async {
        try? await Task.sleep(for: duration)
    }

    static func capture(_ window: NSWindow?, to target: URL) {
        guard let view = window?.contentView?.superview ?? window?.contentView,
              let representation = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: representation)
        try? representation.representation(using: .png, properties: [:])?.write(to: target)
    }
}
#endif
