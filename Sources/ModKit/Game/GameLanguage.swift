import Foundation

public enum GameLanguage {
    public static func appLanguages(for game: GameDefinition) -> [String] {
        if let identifier = game.bundleIdentifier,
           let perApp = CFPreferencesCopyAppValue("AppleLanguages" as CFString, identifier as CFString) as? [String],
           !perApp.isEmpty {
            return perApp
        }
        return Locale.preferredLanguages
    }

    public static func resolve(_ setting: String, for settings: GraftSettings) -> String {
        guard setting.isEmpty || setting.lowercased() == "auto" else { return setting }
        let game = settings.definition
        return preferred(appLanguages(for: game), game: game, gameVersion: AppBundle.shortVersion(at: settings.game.gameApp))
    }

    public static func preferred(_ preferred: [String], game: GameDefinition, gameVersion: String?) -> String {
        let fallback = "USen"
        guard let first = preferred.first else { return fallback }
        let locale = Locale(identifier: first)
        let region = locale.region?.identifier ?? ""
        let script = locale.language.script?.identifier ?? ""
        let candidate: String = switch locale.language.languageCode?.identifier ?? "en" {
        case "ja": "JPja"
        case "de": "EUde"
        case "fr": "EUfr"
        case "es": "EUes"
        case "pt": region == "BR" ? "USpt" : fallback
        case "it": "EUit"
        case "nl": "EUnl"
        case "ru": "EUru"
        case "ko": "KRko"
        case "zh": script == "Hant" || (script.isEmpty && ["TW", "HK", "MO"].contains(region)) ? "TWzh" : "CNzh"
        default: fallback
        }
        let available = game.languages(inVersion: gameVersion).map(\.code)
        return available.contains(candidate) ? candidate : fallback
    }
}
