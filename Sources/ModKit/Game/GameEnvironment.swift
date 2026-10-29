import AppKit
import Darwin

public enum GameEnvironment {
    public static let quitFirstMessage = "Quit the game first: its mod folder can't change while it runs."

    public static func isGameRunning(_ settings: GraftSettings) -> Bool {
        if let identifier = settings.definition.bundleIdentifier,
           !NSRunningApplication.runningApplications(withBundleIdentifier: identifier).isEmpty { return true }
        guard !settings.game.gameApp.isEmpty else { return false }
        let app = URL(fileURLWithPath: settings.game.gameApp).resolvingSymlinksInPath().path + "/"
        var pids = [pid_t](repeating: 0, count: 8192)
        let count = Int(proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.stride)))
        var path = [UInt8](repeating: 0, count: 4 * Int(MAXPATHLEN))
        return pids.prefix(max(count, 0)).contains { pid in
            let length = Int(proc_pidpath(pid, &path, UInt32(path.count)))
            return length > 0 && String(decoding: path[..<length], as: UTF8.self).hasPrefix(app)
        }
    }

    public static func reservedSites(settings: GraftSettings, layout: GameLayout) async throws -> [ReservedSite] {
        guard let relative = settings.definition.tkSharp?.patchSitesScript else { return [] }
        guard MacNativeGames(settings).has(relative) else { return [] }
        let result = try await MacNativeGames(settings).run(
            relative, arguments: ["--version", layout.version, "--build-id", String(layout.buildId.prefix(32)), "--json"])
        guard result.status == 0, let sites = try? JSONDecoder().decode([ReservedSite].self, from: result.output) else {
            throw GraftError("Reading the places the game app patches itself failed: \(result.lastLines(3))")
        }
        return sites
    }
}
