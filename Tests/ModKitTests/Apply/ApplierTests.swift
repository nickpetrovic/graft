import Foundation
import Testing
@testable import ModKit

struct ApplierTests {
    let folder: TemporaryFolder
    let settings: GraftSettings

    init() throws {
        folder = try TemporaryFolder()
        settings = GraftSettings(definition: totk, general: GeneralSettings(),
                                 game: GameSettings(gameApp: folder.path("Game.app"), language: "USen", titleText: ""))
    }

    func steps(_ log: StepLog, buildFails: Bool = false, gameRunning: Bool = false) -> ApplySteps {
        ApplySteps(
            isGameRunning: { gameRunning },
            loadLayout: { layout121 },
            reservedSites: { _ in [] },
            build: { _, _ in
                log.add("build")
                if buildFails { throw GraftError("build failed") }
            },
            installData: { romfs, _ in
                log.add(romfs == nil ? "install nothing" : "install data")
                return "installed"
            }
        )
    }

    func applier(_ mods: [InstalledMod], buildId: String = layout121.buildId, steps: ApplySteps) -> Applier {
        Applier(settings: settings, engine: FakeEngine(mods: mods, buildId: buildId), paths: folder.paths, steps: steps)
    }

    @Test func turningEveryModOffRemovesCodeAndData() async throws {
        let paths = folder.paths
        try folder.write("support/code.pchtxt", "@stop")
        let log = StepLog()
        let applier = applier([mod("a", enabled: false)], steps: steps(log))

        let outcome = try await applier.apply(try await applier.engine.list()) { _ in }

        #expect(log.all == ["install nothing"])
        #expect(!outcome.rebuilt)
        #expect(!FileManager.default.fileExists(atPath: paths.codePatch.path))
        #expect(ApplyState.load(from: paths).appliedModsDigest != nil)
    }

    @Test func aDifferentGameVersionStopsBeforeAnythingIsWritten() async throws {
        let log = StepLog()
        let applier = applier([mod("a")], buildId: "another build", steps: steps(log))

        let error = try await #require(throws: GraftError.self) { try await applier.apply(try await applier.engine.list()) { _ in } }

        #expect(error.message.contains("different version than the game app (1.2.1)"))
        #expect(log.all.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: folder.paths.stateFile.path))
    }

    @Test func aRunningGameStopsTheApplyBeforeAnythingIsWritten() async throws {
        let log = StepLog()
        let applier = applier([mod("a")], steps: steps(log, gameRunning: true))

        let error = try await #require(throws: GraftError.self) { try await applier.apply(try await applier.engine.list()) { _ in } }

        #expect(error.message == GameEnvironment.quitFirstMessage)
        #expect(log.all.isEmpty)
    }

    @Test func aGameWithoutAnEngineCannotBeApplied() async throws {
        let unsupported = Applier(settings: GraftSettings(definition: botw, general: GeneralSettings(), game: GameSettings()),
                                  engine: FakeEngine(mods: [], buildId: ""), paths: folder.paths, steps: steps(StepLog()))

        let error = try await #require(throws: GraftError.self) { try await unsupported.apply([]) { _ in } }

        #expect(error.message == botw.unsupportedReason)
    }

    @Test func aFailedRebuildKeepsTheRecordOfTheLastBuild() async throws {
        let paths = folder.paths
        var previous = ApplyState()
        previous.builtCode[settings.game.gameApp] = "built before"
        try previous.save(to: paths)
        let log = StepLog()
        let applier = applier([mod("a")], steps: steps(log, buildFails: true))

        await #expect(throws: GraftError.self) { try await applier.apply(try await applier.engine.list(), force: true) { _ in } }
        #expect(log.all == ["build"])
        #expect(ApplyState.load(from: paths) == previous)
    }

    @Test func theStagesAreReportedInOrder() async throws {
        let stages = StepLog()
        let applier = applier([mod("a")], steps: steps(StepLog()))

        _ = try await applier.apply(try await applier.engine.list(), force: true) { stage in
            switch stage {
            case .merging(let message): stages.add("merging: \(message)")
            case .checkingCode: stages.add("checking code")
            case .rebuilding(let plan): stages.add(plan.message)
            case .building(let line): stages.add("building: \(line)")
            case .installingData: stages.add("installing data")
            }
        }

        #expect(stages.all == ["merging: Merging 1 mod", "checking code", "Rebuilding the game app as you asked", "installing data"])
    }

    @Test func theApplyCheckNoticesANewGameBuildOrUpdateFile() {
        let mods = [mod("a")]
        var updated = settings
        updated.game.update = "/Games/newer update.nsp"
        let digest = Applier.digest(of: mods, settings: settings, buildId: "build 1")
        #expect(digest == Applier.digest(of: mods, settings: settings, buildId: "build 1"))
        #expect(digest != Applier.digest(of: mods, settings: settings, buildId: "build 2"))
        #expect(digest != Applier.digest(of: mods, settings: updated, buildId: "build 1"))
        #expect(digest != Applier.digest(of: [mod("a", enabled: false)], settings: settings, buildId: "build 1"))
    }

    @Test func theApplyCheckNoticesAnEditedDefinition() {
        let mods = [mod("a")]
        let original = Applier.digest(of: mods, settings: settings, buildId: "build 1")
        var renamed = settings.definition
        renamed.name = "Renamed"
        var moved = settings.definition
        moved.dataFolder = "Elsewhere"
        var retargeted = settings.definition
        if case .tksharp(var tkSharp) = retargeted.mods {
            tkSharp.manifestScript = "games/other/scripts/make_mod_manifest.py"
            retargeted.mods = .tksharp(tkSharp)
        }

        func digest(_ definition: GameDefinition) -> String {
            Applier.digest(of: mods, settings: GraftSettings(definition: definition, general: settings.general, game: settings.game), buildId: "build 1")
        }

        #expect(digest(renamed) == original)
        #expect(digest(moved) != original)
        #expect(digest(retargeted) != original)
    }

    @Test func codeBuiltIntoAnotherGameAppDoesNotRebuildThisOne() async throws {
        let paths = folder.paths
        var previous = ApplyState()
        previous.builtCode["/Apps/Other version.app"] = "built into the other app"
        try previous.save(to: paths)
        let log = StepLog()
        let applier = applier([mod("a")], steps: steps(log))

        let outcome = try await applier.apply(try await applier.engine.list()) { _ in }

        #expect(!outcome.rebuilt)
        #expect(log.all == ["install data"])
        #expect(ApplyState.load(from: paths).builtCode == previous.builtCode)
    }

    @Test func codeBuiltIntoThisGameAppIsRemovedWhenNoModNeedsIt() async throws {
        let paths = folder.paths
        var previous = ApplyState()
        previous.builtCode[settings.game.gameApp] = "built before"
        previous.builtCode["/Apps/Other version.app"] = "built into the other app"
        try previous.save(to: paths)
        let applier = applier([mod("a")], steps: steps(StepLog()))

        let outcome = try await applier.apply(try await applier.engine.list()) { _ in }

        #expect(outcome.rebuilt)
        #expect(ApplyState.load(from: paths).builtCode == ["/Apps/Other version.app": "built into the other app"])
    }
}
