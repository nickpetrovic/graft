import Foundation
import Synchronization
@testable import ModKit

struct FakeEngine: MergingEngine {
    let mods: [InstalledMod]
    let buildId: String
    var updates: [UpdateFile] = []

    func updateVersions(of files: [URL]) async throws -> [UpdateFile] {
        updates.filter { update in files.contains { $0.resolvingSymlinksInPath() == URL(fileURLWithPath: update.path).resolvingSymlinksInPath() } }
    }

    func list() async throws -> [InstalledMod] { mods }
    func add(_ path: URL, progress: @escaping @Sendable (String) -> Void) async throws -> AddedMod { throw GraftError("not used") }
    func remove(_ id: String) async throws -> [InstalledMod] { mods }
    func apply(_ mods: [InstalledMod], force: Bool, stage: @escaping @Sendable (ApplyStage) -> Void) async throws -> ApplyOutcome { throw GraftError("not used") }

    func merge(_ mods: [InstalledMod], into folder: URL, progress: @escaping @Sendable (String) -> Void) async throws -> MergeReport {
        let file = folder.appending(path: "romfs/Pack/Actor/Mod.pack.zs")
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("mod".utf8).write(to: file)
        return MergeReport(buildId: buildId, defaultPatches: [], codePatches: [], ignoredCode: [])
    }
}

final class StepLog: Sendable {
    private let entries = Mutex<[String]>([])

    func add(_ entry: String) {
        entries.withLock { $0.append(entry) }
    }

    var all: [String] {
        entries.withLock { $0 }
    }
}
