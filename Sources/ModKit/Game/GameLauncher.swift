import Foundation

public enum GameLauncher {
    public static func setGameLog(_ enabled: Bool, for game: GameDefinition) {
        guard let variable = game.log?.enableVariable, let identifier = game.bundleIdentifier else { return }
        CFPreferencesSetAppValue(variable as CFString, enabled ? kCFBooleanTrue : kCFBooleanFalse, identifier as CFString)
        CFPreferencesAppSynchronize(identifier as CFString)
    }

    public static func launchArguments(settings: GraftSettings, paths: GraftPaths) -> [String] {
        var arguments: [String] = []
        if let variable = settings.definition.tkSharp?.codeMods?.launchVariable, ApplyState.load(from: paths).codeAtLaunch,
           FileManager.default.fileExists(atPath: paths.codePatch.path) {
            arguments += ["--env", "\(variable)=\(paths.codePatch.path)"]
        }
        return arguments + [settings.game.gameApp]
    }

    public static func launch(settings: GraftSettings, paths: GraftPaths) async throws {
        setGameLog(settings.general.keepGameLog, for: settings.definition)
        LaunchRecord.save(Date(), to: paths)
        do {
            let result = try await ProcessRunner.run(URL(fileURLWithPath: "/usr/bin/open"),
                                                     arguments: launchArguments(settings: settings, paths: paths))
            if result.status != 0 {
                throw GraftError("Could not open the game: \(result.errorText.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
        } catch {
            LaunchRecord.save(nil, to: paths)
            throw error
        }
    }
}
