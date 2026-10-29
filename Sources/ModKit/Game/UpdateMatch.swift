import Foundation

public enum UpdateMatch {
    public static func version(of update: String, settings: GraftSettings, engine: any ModEngine) async throws -> String? {
        guard !update.isEmpty, FileManager.default.fileExists(atPath: update) else { return nil }
        return try await engine.updateVersions(of: [URL(fileURLWithPath: update)]).first { isForGame($0, settings) }?.displayVersion
    }

    public static func find(for settings: GraftSettings, engine: any ModEngine, detector: SettingsDetector? = nil) async throws -> String? {
        guard let version = AppBundle.shortVersion(at: settings.game.gameApp) else { return nil }
        let files = (detector ?? SettingsDetector(game: settings.definition))
            .updateFiles(near: [settings.game.update, settings.game.baseGame] + settings.game.otherApps.map(\.update))
        return try await engine.updateVersions(of: files).first { isForGame($0, settings) && $0.displayVersion == version }?.path
    }

    static func isForGame(_ update: UpdateFile, _ settings: GraftSettings) -> Bool {
        update.titleId.caseInsensitiveCompare(settings.definition.titleId) == .orderedSame
    }
}
