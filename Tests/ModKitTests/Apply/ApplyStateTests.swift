import Foundation
import Testing
@testable import ModKit

struct ApplyStateTests {
    @Test func stateIsSavedAndLoaded() throws {
        let folder = try TemporaryFolder()
        var state = ApplyState()
        state.codeAtLaunch = true
        state.codeStatus = ["a": .ok, "b": .fixed, "c": .unfixable("it writes code")]
        state.recordOwners([0x1000: "a"])
        try state.save(to: folder.paths)

        #expect(ApplyState.load(from: folder.paths) == state)
    }

    @Test func aFieldThatCannotBeReadKeepsTheOthers() throws {
        let folder = try TemporaryFolder()
        try folder.write("support/state.json", #"{"builtCode": {"/Apps/Game.app": "code"}, "codeStatus": {"a": 12}}"#)

        let state = ApplyState.load(from: folder.paths)

        #expect(state.builtCode == ["/Apps/Game.app": "code"])
        #expect(state.codeStatus.isEmpty)
    }

    @Test func aMissingOrDamagedFileStartsEmpty() throws {
        let folder = try TemporaryFolder()
        #expect(ApplyState.load(from: folder.paths) == ApplyState())
        try folder.write("support/state.json", "{ not json")
        #expect(ApplyState.load(from: folder.paths) == ApplyState())
    }

    @Test func anyByteOfAnOwnedWordFindsItsMod() {
        var state = ApplyState()
        state.recordOwners([0x1002: "a", 0x2000: "b"])

        #expect(state.owner(of: 0x1000) == "a")
        #expect(state.owner(of: 0x1003) == "a")
        #expect(state.owner(of: 0x2001) == "b")
        #expect(state.owner(of: 0x3000) == nil)
    }

    @Test func aCrashIsBlamedOnTheCodeThatRanOrTheCallThatLedThere() {
        var state = ApplyState()
        state.recordOwners([0x2000: "caller"])

        #expect(state.crashOwner(CrashReport(programCounter: 0x9000, frames: [0x2004], signal: 11)) == "caller")
        #expect(state.crashOwner(CrashReport(programCounter: 0x2000, frames: [], signal: 11)) == "caller")
        #expect(state.crashOwner(CrashReport(programCounter: nil, frames: [0x2], signal: 11)) == nil)
    }
}
