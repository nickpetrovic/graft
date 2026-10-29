import Foundation
import Testing
@testable import ModKit

struct TkSharpEngineTests {
    let folder: TemporaryFolder
    let settings: GraftSettings

    init() throws {
        folder = try TemporaryFolder()
        settings = GraftSettings(definition: totk, general: GeneralSettings(keysFolder: "/keys"),
                                 game: GameSettings(baseGame: "/base.xci", update: "/update.nsp", language: "USen"))
    }

    func helper(_ body: String) throws -> TkSharpEngine {
        let script = try folder.write("graft-merge", "#!/bin/sh\ncp \"$2\" \"$(dirname \"$0\")/seen-config.json\"\ncommand=\"$3\"\n" + body, executable: true)
        return TkSharpEngine(executable: script, settings: settings, paths: folder.paths)
    }

    func seenConfig() throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: Data(contentsOf: folder.url.appending(path: "seen-config.json"))) as? [String: Any])
    }

    @Test func progressLinesAndResultsAreRead() async throws {
        let engine = try helper("""
            echo '{"event":"progress","message":"Reading Mod.zip"}' >&2
            echo '{"event":"warning","message":"not shown"}' >&2
            echo '{"installed":"m1","replacedIds":[],"keptCodeBuilds":[],"warnings":["left out 2 bytes"],"mods":[{"id":"m1","name":"Mod","version":"","author":"","description":"","enabled":true,"position":0,"dataFiles":3,"textFiles":0,"subSdkFiles":0,"cheatFiles":0,"codePatchBuilds":[],"optionGroups":[]}]}'
            """)
        let messages = StepLog()

        let added = try await engine.add(URL(fileURLWithPath: "/Mod.zip")) { messages.add($0) }

        #expect(messages.all == ["Reading Mod.zip"])
        #expect(added.name == "Mod")
        #expect(added.warnings == ["left out 2 bytes"])
        #expect(added.mods.map(\.dataFiles) == [3])
    }

    @Test func theHelperGetsTheGameFilesAndOtherGamesInItsConfiguration() async throws {
        let engine = try helper(#"echo '{"mods":[]}'"#)

        _ = try await engine.list()

        let config = try seenConfig()
        #expect(config["dataFolder"] as? String == folder.paths.support.path)
        #expect(config["keysFolder"] as? String == "/keys")
        #expect(config["update"] as? String == "/update.nsp")
        #expect(config["titleText"] as? String == "Mods Enabled")
        #expect(config["setup"] == nil)
        let others = (config["otherGames"] as? [[String: Any]])?.compactMap { $0["name"] as? String } ?? []
        #expect(others.contains("Breath of the Wild"))
        #expect(!others.contains("Tears of the Kingdom"))
    }

    @Test func aMergeSendsTheSetupAndTheConfigurationIsRemovedAfterwards() async throws {
        let engine = try helper(#"echo '{"buildId":"abc","defaultPatches":[],"codePatches":[],"ignoredCode":[]}'"#)
        let group = optionGroup("FPS", .singleRequired, ["30", "60"], selected: ["60"])

        let report = try await engine.merge([mod("a", enabled: false, groups: [group]), mod("b")], into: folder.url.appending(path: "merged")) { _ in }

        #expect(report.buildId == "abc")
        let setup = try #require(try seenConfig()["setup"] as? [[String: Any]])
        #expect(setup.compactMap { $0["id"] as? String } == ["a", "b"])
        #expect(setup.compactMap { $0["enabled"] as? Bool } == [false, true])
        #expect((setup[0]["options"] as? [String: [String]]) == ["FPS": ["60"]])
        #expect(try folder.contents(of: "support").isEmpty)
    }

    @Test func theHelpersErrorMessageReachesTheUser() async throws {
        let engine = try helper(#"echo '{"error":"Fake BotW Sword is a Breath of the Wild mod."}'; exit 1"#)

        let error = try await #require(throws: GraftError.self) { try await engine.list() }

        #expect(error.message == "Fake BotW Sword is a Breath of the Wild mod.")
    }

    @Test func aCrashedHelperIsReported() async throws {
        let engine = try helper("echo 'Unhandled exception' >&2; exit 134")

        let error = try await #require(throws: GraftError.self) { try await engine.list() }

        #expect(error.message.contains("stopped unexpectedly (exit 134)"))
        #expect(error.message.contains("Unhandled exception"))
    }

    @Test func unreadableOutputIsReported() async throws {
        let engine = try helper("echo 'not json'")

        let error = try await #require(throws: GraftError.self) { try await engine.list() }

        #expect(error.message.contains("returned something unexpected: not json"))
    }

    @Test func noUpdateFilesMeansNoHelperRun() async throws {
        let engine = try helper("exit 1")
        #expect(try await engine.updateVersions(of: []).isEmpty)
    }
}
