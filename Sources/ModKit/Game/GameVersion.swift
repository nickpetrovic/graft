import Foundation

public struct GameVersion: Sendable, Hashable, Identifiable {
    public let app: String
    public let title: String

    public var id: String { app }

    public static func all(for settings: GraftSettings, found: [String] = []) -> [GameVersion] {
        let fm = FileManager.default
        let current = settings.game.gameApp
        guard fm.fileExists(atPath: current) else { return [] }
        var seen: Set<String> = [current]
        let others = (settings.game.otherApps.map(\.gameApp) + found).filter {
            fm.fileExists(atPath: $0) && AppBundle.bundleIdentifier(at: $0) == settings.definition.bundleIdentifier && seen.insert($0).inserted
        }
        let apps = ([current] + others).map { ($0, AppBundle.shortVersion(at: $0) ?? name(of: $0)) }
        let versions = apps.map(\.1)
        return apps
            .map { app, version in
                GameVersion(app: app, title: versions.filter { $0 == version }.count > 1 ? "\(version) (\(name(of: app)))" : version)
            }
            .sorted { $0.title.compare($1.title, options: .numeric) == .orderedDescending }
    }

    public static func name(of app: String) -> String {
        URL(fileURLWithPath: app).deletingPathExtension().lastPathComponent
    }
}
