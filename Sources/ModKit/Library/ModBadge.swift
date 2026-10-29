import Foundation

public struct ModBadge: Sendable, Hashable, Identifiable {
    public enum Kind: Sendable, Hashable {
        case fixed, partial, wrongVersion, wontWork
    }

    public let kind: Kind
    public let title: String
    public let help: String

    public var id: String { title }

    public static func badges(for mod: InstalledMod, layout: GameLayout?, status: CodeStatus?) -> [ModBadge] {
        var badges: [ModBadge] = []
        let version = layout?.displayVersion ?? "this version"
        if mod.changesCode(buildId: layout?.buildId) {
            switch status {
            case .fixed?:
                badges.append(ModBadge(kind: .fixed, title: "Fixed for Mac",
                                       help: "Its code stored values inside the game's read-only code memory. Graft moved them to writable memory."))
            case .unfixable(let reason)?:
                badges.append(ModBadge(kind: .wontWork, title: "Won't work", help: reason))
            case .ok?, nil:
                break
            }
        } else if !mod.codePatchBuilds.isEmpty {
            badges.append(ModBadge(kind: .wrongVersion, title: mod.hasData ? "Code not for \(version)" : "Not for \(version)",
                                   help: "Its code patches are for a different game version, so they are left out."))
        }
        if mod.cheatFiles > 0 {
            badges.append(ModBadge(kind: .partial, title: "Cheats not used",
                                   help: "It includes cheat files. The Mac app doesn't load cheats, so only its other parts apply."))
        }
        if mod.subSdkFiles > 0 {
            badges.append(ModBadge(kind: .partial, title: "Partly works",
                                   help: "It ships an extra code module (subsdk) that the Mac app can't load. Its data files and main patches still apply, but the features in that module are missing."))
        }
        return badges
    }
}
