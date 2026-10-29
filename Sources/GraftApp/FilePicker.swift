import AppKit
import ModKit

enum FilePicker {
    @MainActor
    static func choose(_ kind: GameDefinition.FileSetting.Kind, startingAt path: String = "") -> String? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = kind == .folder
        panel.canChooseFiles = kind != .folder
        panel.treatsFilePackagesAsDirectories = false
        if kind == .application {
            panel.allowedContentTypes = [.application]
        }
        if !path.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: path).deletingLastPathComponent()
        }
        guard panel.runModal() == .OK else { return nil }
        return panel.url?.path
    }
}
