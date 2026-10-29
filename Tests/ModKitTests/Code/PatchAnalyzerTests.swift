import Foundation
import Testing
@testable import ModKit

struct PatchAnalyzerTests {
    @Test func aCodeCaveIsRelocatedLikeTheHandFix() throws {
        let original = try codePatch("code-cave")
        let handFixed = try codePatch("code-cave-fixed")
        #expect(original.entries.count == 11)

        let analysis = try PatchAnalyzer.analyze(entries: original.entries, layout: layout121)

        #expect(analysis.outcome == .relocated(movedInstructions: 2, droppedInitializers: 3))
        #expect(Set(analysis.entries) == Set(handFixed.entries))
        #expect(analysis.unsupportedInstructions.isEmpty)
    }

    @Test func replacedInstructionsNeedNoChange() throws {
        let patch = try codePatch("nops")
        #expect(patch.entries.count == 3)

        let analysis = try PatchAnalyzer.analyze(entries: patch.entries, layout: layout121)

        #expect(analysis.outcome == .unchanged)
        #expect(Set(analysis.entries) == Set(patch.entries))
    }

    @Test func adrpEncodingMatchesTheHandFix() {
        #expect(PatchAnalyzer.encodeAdrp(register: 9, at: 0xf0000, target: 0x472b000) == [0xC9, 0x31, 0x02, 0xF0])
        #expect(PatchAnalyzer.encodeAdrp(register: 0, at: 0xf1168, target: 0x472b000) == [0xC0, 0x31, 0x02, 0xD0])
    }

    @Test func systemCallsAndX18AreReported() throws {
        let entries = [
            PatchEntry(address: 0x1000, hex: "010000D4")!,
            PatchEntry(address: 0x1004, hex: "520280D2")!,
            PatchEntry(address: 0x1008, hex: "1F2003D5")!,
        ]
        let analysis = try PatchAnalyzer.analyze(entries: entries, layout: layout121)
        #expect(analysis.unsupportedInstructions.count == 2)
        #expect(analysis.unsupportedInstructions.contains { $0.contains("system call") })
        #expect(analysis.unsupportedInstructions.contains { $0.contains("x18") })
    }

    @Test func unfixableWhenTheStartingValueIsNotZero() throws {
        var entries = try codePatch("code-cave").entries
        entries.removeAll { $0.address == 0xf0f08 }
        entries.append(PatchEntry(address: 0xf0f08, hex: "01000000")!)

        let analysis = try PatchAnalyzer.analyze(entries: entries, layout: layout121)

        guard case .unfixable(let reason) = analysis.outcome else {
            Issue.record("expected unfixable, got \(analysis.outcome)")
            return
        }
        #expect(reason.contains("starting value"))
    }

    @Test func aHandFixedCodeCaveIsLeftAsIs() throws {
        let handFixed = try codePatch("code-cave-fixed")
        let analysis = try PatchAnalyzer.analyze(entries: handFixed.entries, layout: layout121, owner: "Cave")
        #expect(analysis.outcome == .unchanged)
        #expect(!analysis.freeRanges.isEmpty)
    }

    @Test func aSecondCopyCannotShareFreeMemory() throws {
        let original = try codePatch("code-cave")
        let first = try PatchAnalyzer.analyze(entries: original.entries, layout: layout121, owner: "Cave A")
        let second = try PatchAnalyzer.analyze(entries: original.entries, layout: layout121, owner: "Cave B",
                                               occupied: first.freeRanges)
        guard case .unfixable(let reason) = second.outcome else {
            Issue.record("expected the second copy to be left out, got \(second.outcome)")
            return
        }
        #expect(reason.contains("Cave A"))
    }

    @Test func adrpAddStoreIsRelocated() throws {
        let entries = [
            adrp(9, at: 0xe0000, page: codePage),
            instruction(0xe0004, addX(9, 9, 0x100)),
            instruction(0xe0008, strW(1, base: 9, offset: 0)),
            instruction(0xe000c, 0xD65F03C0),
            PatchEntry(address: UInt32(codePage) + 0x100, hex: "00000000")!,
        ]
        let analysis = try PatchAnalyzer.analyze(entries: entries, layout: layout121)
        #expect(analysis.outcome == .relocated(movedInstructions: 1, droppedInitializers: 1))
        let moved = try #require(analysis.entries.first { $0.address == 0xe0000 })
        #expect(moved == adrp(9, at: 0xe0000, page: UInt64(layout121.freeStart)))
        #expect(analysis.freeRanges == [FreeRange(start: UInt64(layout121.freeStart) + 0x100, end: UInt64(layout121.freeStart) + 0x104, owner: "")])
    }

    @Test func overwritingTheBaseThroughItsWRegisterEndsTheTrace() throws {
        let entries = [
            adrp(9, at: 0xe0000, page: codePage),
            instruction(0xe0004, ldrW(9, base: 9, offset: 0x10)),
            instruction(0xe0008, strW(1, base: 9, offset: 0x20)),
            instruction(0xe000c, 0xD65F03C0),
        ]
        let analysis = try PatchAnalyzer.analyze(entries: entries, layout: layout121)
        #expect(analysis.outcome == .unchanged)
    }

    @Test func valueOnTheNextPageIsLeftOut() throws {
        let entries = [
            adrp(9, at: 0xe0000, page: codePage),
            instruction(0xe0004, strX(0, base: 9, offset: 0x1008)),
            instruction(0xe0008, 0xD65F03C0),
            PatchEntry(address: UInt32(codePage) + 0x1008, hex: "0000000000000000")!,
        ]
        let analysis = try PatchAnalyzer.analyze(entries: entries, layout: layout121)
        guard case .unfixable = analysis.outcome else {
            Issue.record("expected the patch to be left out, got \(analysis.outcome)")
            return
        }
    }

    @Test func readingGameDataOnAMovedPageIsLeftOut() throws {
        let entries = [
            adrp(9, at: 0xe0000, page: codePage),
            instruction(0xe0004, ldrX(10, base: 9, offset: 0x100)),
            instruction(0xe0008, strX(10, base: 9, offset: 0x108)),
            instruction(0xe000c, 0xD65F03C0),
            PatchEntry(address: UInt32(codePage) + 0x108, hex: "0000000000000000")!,
        ]
        let analysis = try PatchAnalyzer.analyze(entries: entries, layout: layout121)
        guard case .unfixable(let reason) = analysis.outcome else {
            Issue.record("expected the patch to be left out, got \(analysis.outcome)")
            return
        }
        #expect(reason.contains("never sets"))
    }

    @Test func writesAfterABranchOrACallAreFound() throws {
        let afterBranch = [
            adrp(9, at: 0xe0000, page: codePage),
            instruction(0xe0004, 0x3400_0040),
            instruction(0xe0008, strW(1, base: 9, offset: 0x100)),
            instruction(0xe000c, 0xD65F03C0),
            PatchEntry(address: UInt32(codePage) + 0x100, hex: "00000000")!,
        ]
        let afterCall = [
            adrp(19, at: 0xe0000, page: codePage),
            instruction(0xe0004, 0x9400_0400),
            instruction(0xe0008, strW(0, base: 19, offset: 0x100)),
            instruction(0xe000c, 0xD65F03C0),
            PatchEntry(address: UInt32(codePage) + 0x100, hex: "00000000")!,
        ]
        for entries in [afterBranch, afterCall] {
            let analysis = try PatchAnalyzer.analyze(entries: entries, layout: layout121)
            #expect(analysis.outcome == .relocated(movedInstructions: 1, droppedInitializers: 1))
        }
    }

    @Test func atomicUpdatesCountAsWrites() throws {
        let entries = [
            adrp(9, at: 0xe0000, page: codePage),
            instruction(0xe0004, addX(9, 9, 0x100)),
            instruction(0xe0008, 0xB821_0122),
            instruction(0xe000c, 0xD65F03C0),
            PatchEntry(address: UInt32(codePage) + 0x100, hex: "00000000")!,
        ]
        let analysis = try PatchAnalyzer.analyze(entries: entries, layout: layout121)
        #expect(analysis.outcome == .relocated(movedInstructions: 1, droppedInitializers: 1))
    }

    @Test func aPointerThatEscapesIsNotCalledSafe() throws {
        let entries = [
            adrp(9, at: 0xe0000, page: codePage),
            instruction(0xe0004, strX(9, base: 31, offset: 8)),
            instruction(0xe0008, 0xD65F03C0),
            PatchEntry(address: UInt32(codePage) + 0x100, hex: "00000000")!,
        ]
        let analysis = try PatchAnalyzer.analyze(entries: entries, layout: layout121)
        guard case .unfixable(let reason) = analysis.outcome else {
            Issue.record("expected the patch to be left out, got \(analysis.outcome)")
            return
        }
        #expect(reason.contains("can't follow every use"))
    }

    @Test func writingTheGamesOwnDataIsLeftOut() throws {
        let entries = [
            adrp(8, at: 0xe0000, page: 0x200000),
            instruction(0xe0004, strW(0, base: 8, offset: 0x10)),
            instruction(0xe0008, 0xD65F03C0),
        ]
        let analysis = try PatchAnalyzer.analyze(entries: entries, layout: layout121)
        guard case .unfixable(let reason) = analysis.outcome else {
            Issue.record("expected the patch to be left out, got \(analysis.outcome)")
            return
        }
        #expect(reason.contains("belongs to the game"))
    }

    @Test func aCrashAtTheStartOfMainDoesNotTrap() {
        var state = ApplyState()
        state.recordOwners([0xffff_fffc: "a"])
        #expect(state.crashOwner(CrashReport(programCounter: nil, frames: [0, 2], signal: 11)) == nil)
        #expect(state.owner(of: 0xffff_fffe) == "a")
    }
}
