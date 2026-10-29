import Foundation

public enum LaunchRecord {
    public static func load(from paths: GraftPaths) -> Date? {
        guard let text = try? String(contentsOf: paths.launchFile, encoding: .utf8) else { return nil }
        return try? Date(text.trimmingCharacters(in: .whitespacesAndNewlines), strategy: .iso8601)
    }

    public static func save(_ date: Date?, to paths: GraftPaths) {
        guard let date else {
            try? FileManager.default.removeItem(at: paths.launchFile)
            return
        }
        try? FileManager.default.createDirectory(at: paths.support, withIntermediateDirectories: true)
        try? (date.formatted(.iso8601) + "\n").write(to: paths.launchFile, atomically: true, encoding: .utf8)
    }
}
