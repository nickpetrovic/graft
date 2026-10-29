import Foundation

public enum AppBundle {
    public static func info(at path: String) -> [String: Any]? {
        NSDictionary(contentsOf: URL(fileURLWithPath: path).appending(path: "Contents/Info.plist")) as? [String: Any]
    }

    public static func bundleIdentifier(at path: String) -> String? {
        info(at: path)?["CFBundleIdentifier"] as? String
    }

    public static func shortVersion(at path: String) -> String? {
        info(at: path)?["CFBundleShortVersionString"] as? String
    }

    public static func requireShortVersion(at path: String) throws -> String {
        guard let version = shortVersion(at: path) else {
            throw GraftError(path.isEmpty ? "Choose the game app first." : "Graft couldn't read the version of the game app at \(path).")
        }
        return version
    }
}
