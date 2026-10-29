import Foundation

public struct GraftPaths: Sendable, Equatable {
    public let root: URL
    public let support: URL
    public let gameData: URL
    public let gameLog: URL

    public init(root: URL, support: URL, gameData: URL, gameLog: URL) {
        self.root = root
        self.support = support
        self.gameData = gameData
        self.gameLog = gameLog
    }

    public static var standardRoot: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "Graft", directoryHint: .isDirectory)
    }

    public static func standard(for game: GameDefinition) -> GraftPaths {
        let fm = FileManager.default
        let applicationSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return GraftPaths(
            root: standardRoot,
            support: standardRoot.appending(path: "games/\(game.id)", directoryHint: .isDirectory),
            gameData: applicationSupport.appending(path: "MacNativeGames/\(game.dataFolder ?? game.id)", directoryHint: .isDirectory),
            gameLog: fm.homeDirectoryForCurrentUser.appending(path: "Library/Logs/MacNativeGames/\(game.logFileName).log")
        )
    }

    public var appSettingsFile: URL { Self.appSettingsFile(root: root) }

    public static func appSettingsFile(root: URL) -> URL { root.appending(path: "settings.json") }
    public var settingsFile: URL { support.appending(path: "game-settings.json") }
    public var stateFile: URL { support.appending(path: "state.json") }
    public var launchFile: URL { support.appending(path: "last-launch.txt") }
    public func helperConfig(id: UUID) -> URL { support.appending(path: "helper-config-\(id.uuidString).json") }
    public var libraryLock: URL { support.appending(path: "library.lock") }
    public var applyLock: URL { support.appending(path: "apply.lock") }
    public var library: URL { support.appending(path: "library", directoryHint: .isDirectory) }
    public var merged: URL { support.appending(path: "merged", directoryHint: .isDirectory) }
    public var buildInput: URL { support.appending(path: "build-input", directoryHint: .isDirectory) }
    public var codePatch: URL { support.appending(path: "code.pchtxt") }
    public var setups: URL { support.appending(path: "setups", directoryHint: .isDirectory) }

    public func modsFolder(version: String) -> URL {
        gameData.appending(path: "mods/\(version)", directoryHint: .isDirectory)
    }
}
