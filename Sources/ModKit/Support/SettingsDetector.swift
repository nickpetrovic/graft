import Foundation

public struct SettingsDetector: Sendable {
    let game: GameDefinition
    let home: URL
    let applications: URL
    let includeProtectedFolders: Bool

    public init(game: GameDefinition, home: URL = FileManager.default.homeDirectoryForCurrentUser,
                applications: URL = URL(fileURLWithPath: "/Applications"), includeProtectedFolders: Bool = false) {
        self.game = game
        self.home = home
        self.applications = applications
        self.includeProtectedFolders = includeProtectedFolders
    }

    public func detect() async -> GraftSettings {
        let gameFiles = game.unsupportedReason == nil ? findGameFiles() : (base: nil, update: nil)
        let gameFolder = gameFiles.base.map { URL(fileURLWithPath: $0).deletingLastPathComponent() }
        let general = Self.detectGeneral(home: home, near: gameFolder)
        let gameApp = findGameApp(near: [gameFiles.base, gameFiles.update].compactMap { $0 })
        let recordedWorkFolder = game.app?.workFolderKey.flatMap { key in gameApp.flatMap { AppBundle.info(at: $0)?[key] as? String } }
        let files = GameSettings(
            gameApp: gameApp ?? "",
            workFolder: recordedWorkFolder ?? firstExisting([home.appending(path: "Games/\(game.workFolderName)")]
                + (gameFolder.map { [$0.appending(path: game.workFolderName)] } ?? [])
                + portFolder(in: general.macNativeGames), containing: game.workTreeName) ?? "",
            baseGame: gameFiles.base ?? "",
            update: gameFiles.update ?? "")
        return GraftSettings(definition: game, general: general, game: files)
    }

    public static func detectGeneral(home: URL = FileManager.default.homeDirectoryForCurrentUser, near gameFolder: URL? = nil) -> GeneralSettings {
        GeneralSettings(
            macNativeGames: firstExisting(["Projects", "Developer", "Code", "src", ""].map {
                home.appending(path: $0).appending(path: "MacNativeGames")
            }, containing: MacNativeGames.folderMarker) ?? "",
            keysFolder: firstExisting([
                home.appending(path: ".switch"),
                home.appending(path: "Games/Switch/keys"),
                home.appending(path: "Library/Application Support/Ryujinx/system"),
            ] + (gameFolder.map { [$0, $0.deletingLastPathComponent().appending(path: "keys")] } ?? []),
                containing: "prod.keys") ?? "")
    }

    func portFolder(in macNativeGames: String) -> [URL] {
        guard !macNativeGames.isEmpty, let folder = game.macNativeGamesFolder else { return [] }
        return [URL(fileURLWithPath: macNativeGames).appending(path: "games/\(folder)/\(game.workFolderName)")]
    }

    func appFolders(near paths: [String]) -> [URL] {
        Self.appFolders(home: home, applications: applications, near: paths)
    }

    public static func appFolders(home: URL = FileManager.default.homeDirectoryForCurrentUser, applications: URL = URL(fileURLWithPath: "/Applications"),
                                  near paths: [String] = []) -> [URL] {
        let fm = FileManager.default
        let games = home.appending(path: "Games")
        let insideGames = ((try? fm.contentsOfDirectory(at: games, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? [])
            .filter { $0.pathExtension != "app" && (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .sorted { $0.path < $1.path }
        let nearby = paths.filter { !$0.isEmpty }.map { URL(fileURLWithPath: $0).deletingLastPathComponent() }
        var seen: Set<String> = []
        return (nearby + [games] + insideGames + [home.appending(path: "Applications"), applications])
            .filter { seen.insert($0.standardizedFileURL.path).inserted }
    }

    public func findGameApp(near paths: [String] = []) -> String? {
        guard let appName = game.appFileName else { return nil }
        return firstExisting(appFolders(near: paths).map { $0.appending(path: appName) })
    }

    public func findGameApps(near paths: [String] = []) -> [String] {
        guard let identifier = game.bundleIdentifier else { return [] }
        return appFolders(near: paths).flatMap { folder in
            ((try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? [])
                .filter { $0.pathExtension == "app" && AppBundle.bundleIdentifier(at: $0.path) == identifier }
                .map(\.path)
                .sorted()
        }
    }

    public func updateFiles(near paths: [String]) -> [URL] {
        let nearby = paths.filter { !$0.isEmpty }.map { URL(fileURLWithPath: $0).deletingLastPathComponent() }
        var seen: Set<String> = []
        return (files(under: home.appending(path: "Games"), depth: 4) + nearby.flatMap { files(under: $0, depth: 1) })
            .filter { ["nsp", "xci"].contains($0.pathExtension.lowercased()) && seen.insert($0.standardizedFileURL.path).inserted }
    }

    func findGameFiles() -> (base: String?, update: String?) {
        var base: String?
        var update: (path: String, version: Int)?
        let folders = includeProtectedFolders ? ["Games", "Downloads", "Documents"] : ["Games"]
        let roots = folders.map { home.appending(path: $0) }
        for file in roots.flatMap({ files(under: $0, depth: 4) }) {
            let name = file.lastPathComponent.uppercased()
            guard ["xci", "nsp"].contains(file.pathExtension.lowercased()) else { continue }
            if base == nil, name.contains(game.titleId.uppercased()) {
                base = file.path
            } else if let updateTitleId = game.updateTitleId, name.contains(updateTitleId.uppercased()) {
                let version = Self.version(inFileName: name)
                if version >= update?.version ?? -1 { update = (file.path, version) }
            }
        }
        return (base, update?.path)
    }

    static func version(inFileName name: String) -> Int {
        guard let match = name.firstMatch(of: /\[V(\d+)\]/) else { return 0 }
        return Int(match.1) ?? 0
    }

    func files(under root: URL, depth: Int) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: root, includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { return [] }
        var found: [URL] = []
        for case let url as URL in enumerator {
            if (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true {
                found.append(url)
            } else if enumerator.level >= depth {
                enumerator.skipDescendants()
            }
        }
        return found.sorted { $0.path < $1.path }
    }

    func firstExisting(_ candidates: [URL], containing child: String? = nil) -> String? {
        Self.firstExisting(candidates, containing: child)
    }

    static func firstExisting(_ candidates: [URL], containing child: String? = nil) -> String? {
        candidates.first { candidate in
            FileManager.default.fileExists(atPath: child.map { candidate.appending(path: $0).path } ?? candidate.path)
        }?.path
    }
}
