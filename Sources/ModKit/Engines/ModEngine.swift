import Foundation

public protocol ModEngine: Sendable {
    func list() async throws -> [InstalledMod]
    func add(_ path: URL, progress: @escaping @Sendable (String) -> Void) async throws -> AddedMod
    func remove(_ id: String) async throws -> [InstalledMod]
    func apply(_ mods: [InstalledMod], force: Bool, stage: @escaping @Sendable (ApplyStage) -> Void) async throws -> ApplyOutcome
    func importableLibrary() -> ImportableLibrary?
    func importLibrary(_ library: ImportableLibrary) async throws -> URL?
    func readCodePatch(_ file: URL) async throws -> CodePatchFile
    func updateVersions(of files: [URL]) async throws -> [UpdateFile]
}

public protocol MergingEngine: ModEngine {
    func merge(_ mods: [InstalledMod], into folder: URL, progress: @escaping @Sendable (String) -> Void) async throws -> MergeReport
}

public struct ImportableLibrary: Sendable, Equatable {
    public let manager: String
    public let location: URL

    public init(manager: String, location: URL) {
        self.manager = manager
        self.location = location
    }
}

extension ModEngine {
    public func importableLibrary() -> ImportableLibrary? { nil }

    public func importLibrary(_ library: ImportableLibrary) async throws -> URL? {
        throw GraftError("This game's mods can't be imported from \(library.manager).")
    }

    public func readCodePatch(_ file: URL) async throws -> CodePatchFile {
        throw GraftError("Graft can't read code patches for this game.")
    }

    public func updateVersions(of files: [URL]) async throws -> [UpdateFile] { [] }
}

public enum ModEngines {
    public static func make(settings: GraftSettings, paths: GraftPaths) throws -> any ModEngine {
        let game = settings.definition
        guard let engineSettings = game.mods.engineSettings else {
            throw GraftError(game.unsupportedReason ?? "Graft can't manage \(game.name) mods yet.")
        }
        return try engineSettings.makeEngine(settings: settings, paths: paths)
    }
}
