import Foundation

public struct GeneralSettings: Codable, Sendable, Equatable {
    public var macNativeGames: String
    public var keysFolder: String
    public var keepGameLog: Bool

    public init(macNativeGames: String = "", keysFolder: String = "", keepGameLog: Bool = true) {
        self.macNativeGames = macNativeGames
        self.keysFolder = keysFolder
        self.keepGameLog = keepGameLog
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = GeneralSettings()
        self.init(macNativeGames: try container.decodeIfPresent(String.self, forKey: .macNativeGames) ?? defaults.macNativeGames,
                  keysFolder: try container.decodeIfPresent(String.self, forKey: .keysFolder) ?? defaults.keysFolder,
                  keepGameLog: try container.decodeIfPresent(Bool.self, forKey: .keepGameLog) ?? defaults.keepGameLog)
    }
}

public struct GameSettings: Codable, Sendable, Equatable {
    public struct OtherApp: Codable, Sendable, Equatable {
        public var gameApp: String
        public var update: String

        public init(gameApp: String, update: String) {
            self.gameApp = gameApp
            self.update = update
        }
    }

    public var gameApp: String
    public var workFolder: String
    public var baseGame: String
    public var update: String
    public var language: String
    public var titleText: String
    public var otherApps: [OtherApp]

    public init(gameApp: String = "", workFolder: String = "", baseGame: String = "", update: String = "",
                language: String = "auto", titleText: String = "Mods Enabled", otherApps: [OtherApp] = []) {
        self.gameApp = gameApp
        self.workFolder = workFolder
        self.baseGame = baseGame
        self.update = update
        self.language = language
        self.titleText = titleText
        self.otherApps = otherApps
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = GameSettings()
        self.init(gameApp: try container.decodeIfPresent(String.self, forKey: .gameApp) ?? defaults.gameApp,
                  workFolder: try container.decodeIfPresent(String.self, forKey: .workFolder) ?? defaults.workFolder,
                  baseGame: try container.decodeIfPresent(String.self, forKey: .baseGame) ?? defaults.baseGame,
                  update: try container.decodeIfPresent(String.self, forKey: .update) ?? defaults.update,
                  language: try container.decodeIfPresent(String.self, forKey: .language) ?? defaults.language,
                  titleText: try container.decodeIfPresent(String.self, forKey: .titleText) ?? defaults.titleText,
                  otherApps: try container.decodeIfPresent([OtherApp].self, forKey: .otherApps) ?? defaults.otherApps)
    }

    public mutating func remember(_ previous: GameSettings) {
        guard gameApp != previous.gameApp else { return }
        let chosen = otherApps.first { $0.gameApp == gameApp }
        otherApps.removeAll { $0.gameApp == gameApp || $0.gameApp == previous.gameApp }
        if !previous.gameApp.isEmpty {
            otherApps.insert(OtherApp(gameApp: previous.gameApp, update: previous.update), at: 0)
        }
        if let chosen, update == previous.update {
            update = chosen.update
        }
    }

    public subscript(role: GameDefinition.FileSetting.Role) -> String {
        get {
            switch role {
            case .gameApp: gameApp
            case .baseGame: baseGame
            case .update: update
            case .workFolder: workFolder
            }
        }
        set {
            switch role {
            case .gameApp: gameApp = newValue
            case .baseGame: baseGame = newValue
            case .update: update = newValue
            case .workFolder: workFolder = newValue
            }
        }
    }
}

public struct GraftSettings: Sendable, Equatable {
    public let definition: GameDefinition
    public var general: GeneralSettings
    public var game: GameSettings

    public init(definition: GameDefinition, general: GeneralSettings, game: GameSettings) {
        self.definition = definition
        self.general = general
        self.game = game
    }
}
