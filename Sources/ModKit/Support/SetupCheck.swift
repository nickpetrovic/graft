import Foundation

public struct SetupCheck: Sendable, Equatable {
    public struct FileProblem: Sendable, Equatable {
        public let file: GameDefinition.FileSetting
        public let message: String
    }

    public let macNativeGames: String?
    public let keysFolder: String?
    public let files: [FileProblem]
    public let definition: [String]

    public init(_ settings: GraftSettings, updateVersion: String? = nil) {
        let general = GeneralCheck(settings.general)
        macNativeGames = general.macNativeGames
        keysFolder = general.keysFolder

        files = settings.definition.unsupportedReason != nil ? [] : settings.definition.files.compactMap { file in
            Self.problem(for: file, in: settings, updateVersion: updateVersion).map { FileProblem(file: file, message: $0) }
        }

        definition = GameCheck.blockingProblems(for: settings)
    }

    public var general: [String] { [macNativeGames, keysFolder].compactMap { $0 } }

    public var gameProblems: [String] { files.map(\.message) + definition }

    public var problems: [String] { general + gameProblems }

    public func problem(for role: GameDefinition.FileSetting.Role) -> String? {
        files.first { $0.file.role == role }?.message
    }

    static func problem(for file: GameDefinition.FileSetting, in settings: GraftSettings, updateVersion: String? = nil) -> String? {
        let fm = FileManager.default
        let game = settings.definition
        let path = settings.game[file.role]
        let appVersion = AppBundle.shortVersion(at: settings.game.gameApp)
        if path.isEmpty {
            if file.role == .update, let appVersion { return "Choose the \(appVersion) update." }
            return "Choose the \(file.label.lowercased())."
        }
        switch file.role {
        case .gameApp:
            guard fm.fileExists(atPath: path) else { return "Graft can't find the game app." }
            if let identifier = AppBundle.bundleIdentifier(at: path), let expected = game.bundleIdentifier, identifier != expected {
                let other = GameCatalog.shared.game(bundleIdentifier: identifier)?.name ?? GameTemplates.shared.template(bundleIdentifier: identifier)?.definition.name
                return other.map { "This game app is for \($0), not \(game.name)." }
                    ?? "This app's identifier is \(identifier), but \(game.name) expects \(expected). Choose the right game app, or edit the game."
            }
            return nil
        case .baseGame:
            return fm.fileExists(atPath: path) ? nil : "Graft can't find the base game file."
        case .update:
            guard fm.fileExists(atPath: path) else { return "Graft can't find the update file." }
            if let updateVersion, let appVersion, updateVersion != appVersion {
                return "This update is \(updateVersion), but the game app is \(appVersion). Choose the \(appVersion) update."
            }
            return nil
        case .workFolder:
            let tree = URL(fileURLWithPath: path).appending(path: game.workTreeName)
            guard fm.fileExists(atPath: tree.appending(path: "extracted").path) else {
                return "This folder isn't a work folder MacNativeGames built the game in."
            }
            guard game.mods.engineSettings != nil else { return nil }
            let python = MacNativeGames(settings).python
            guard !fm.isExecutableFile(atPath: python.path) else { return nil }
            if let fileMods = game.fileMods, fileMods.pythonIsFullPath {
                return "Graft can't run the Python at \(fileMods.python). Check the Python in Edit Game."
            }
            return "The work folder has no Python environment yet. Build the game app with MacNativeGames once to create it."
        }
    }
}

public struct GeneralCheck: Sendable, Equatable {
    public let macNativeGames: String?
    public let keysFolder: String?

    public init(_ general: GeneralSettings) {
        macNativeGames = general.macNativeGames.isEmpty ? "Choose your MacNativeGames folder."
            : MacNativeGames.presentFolder(general) != nil ? nil
            : "The folder \(general.macNativeGames) has no \(MacNativeGames.folderMarker), so it isn't a MacNativeGames folder."
        let keys = URL(fileURLWithPath: general.keysFolder).appending(path: "prod.keys")
        keysFolder = general.keysFolder.isEmpty ? "Choose the folder with your keys."
            : FileManager.default.fileExists(atPath: keys.path) ? nil : "The folder \(general.keysFolder) has no prod.keys."
    }

    public var problems: [String] { [macNativeGames, keysFolder].compactMap { $0 } }
}
