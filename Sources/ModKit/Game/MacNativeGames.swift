import Foundation

public struct MacNativeGames: Sendable {
    static let folderMarker = "build_app.py"
    static let nothingToInstall = "replaces or adds no file"
    static let buildError = "ERROR: "
    static let displayLinkFailure = "native display link"
    static let romfsOverlayFailure = "RomFS overlay"
    static let failure = " FAIL: "
    static let crashSignal = " signal="
    static let crashFrame = "frame lr="
    static let moduleOffset = " offset="
    static let messages = [nothingToInstall, buildError, displayLinkFailure, romfsOverlayFailure, failure, crashSignal, crashFrame, moduleOffset]

    public let settings: GraftSettings

    public init(_ settings: GraftSettings) {
        self.settings = settings
    }

    public var folder: URL? {
        settings.general.macNativeGames.isEmpty ? nil : URL(fileURLWithPath: settings.general.macNativeGames)
    }

    public var python: URL {
        let workFolder = URL(fileURLWithPath: settings.game.workFolder)
        if let fileMods = settings.definition.fileMods { return fileMods.python(in: workFolder) }
        return workFolder.appending(path: "\(settings.definition.workTreeName)/.venv/bin/python")
    }

    public var presentFolder: URL? { Self.presentFolder(settings.general) }

    public static func presentFolder(_ general: GeneralSettings) -> URL? {
        guard !general.macNativeGames.isEmpty else { return nil }
        let folder = URL(fileURLWithPath: general.macNativeGames)
        return FileManager.default.fileExists(atPath: folder.appending(path: folderMarker).path) ? folder : nil
    }

    public func script(_ relative: String) -> URL? {
        folder?.appending(path: relative)
    }

    public func has(_ relative: String) -> Bool {
        script(relative).map { FileManager.default.fileExists(atPath: $0.path) } ?? false
    }

    public func run(_ relative: String, arguments: [String], inFolder: Bool = false,
                    lineSource: ProcessRunner.LineSource = .standardError,
                    onLine: @escaping @Sendable (String) -> Void = { _ in }) async throws -> ProcessResult {
        guard let folder, let script = script(relative) else {
            throw GraftError("Choose your MacNativeGames folder in Settings first.")
        }
        return try await ProcessRunner.run(python, arguments: ["-E", script.path] + arguments,
                                           workingDirectory: inFolder ? folder : nil, lineSource: lineSource, onLine: onLine)
    }
}
