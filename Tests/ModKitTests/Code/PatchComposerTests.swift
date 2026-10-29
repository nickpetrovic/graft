import Foundation
import Testing
@testable import ModKit

struct PatchComposerTests {
    @Test func composedCodeRecordsWhichModOwnsEachAddress() throws {
        let cave = try codePatch("code-cave")
        let nops = try codePatch("nops")
        let report = MergeReport(
            buildId: layout121.buildId,
            defaultPatches: [PatchEntry(address: 0x1acb308, hex: "08408052")!],
            codePatches: [
                ModCodePatch(modId: "n", modName: "Nops", entries: nops.entries),
                ModCodePatch(modId: "c", modName: "Code Cave", entries: cave.entries),
            ],
            ignoredCode: [])

        let composed = try PatchComposer.compose(report: report, layout: layout121)

        #expect(composed.entryCount == 1 + 3 + 8)
        var state = ApplyState()
        state.recordOwners(composed.owners)
        #expect(state.owner(of: 0xf0014) == "c")
        #expect(state.owner(of: 0x1111000) == "n")
        #expect(state.owner(of: 0x1acb308) == nil)
        let crash = try #require(CrashReport.parse(try fixture("crash.log"), prefix: totk.logLinePrefix))
        #expect(state.crashOwner(crash) == "c")
        #expect(composed.pchtxt.hasPrefix("@nsobid-9B4E43650501A4D4489B4BBFDB740F26AF3CF850"))
        #expect(composed.pchtxt.contains("@flag offset_shift 0x100"))
        #expect(composed.pchtxt.contains("000f0000 C93102F0"))
        #expect(!composed.pchtxt.contains("000f0f00"))
    }

    @Test func modsTouchingTheAppsOwnPatchSitesAreLeftOut() throws {
        let report = MergeReport(
            buildId: layout121.buildId,
            defaultPatches: [],
            codePatches: [ModCodePatch(modId: "f", modName: "Frame Mod",
                                       entries: [PatchEntry(address: 0x7ede80, hex: "1F2003D5")!])],
            ignoredCode: [])
        let reserved = [ReservedSite(label: "game_patches.c:213", offset: 0x7ede80, size: 4)]

        let composed = try PatchComposer.compose(report: report, layout: layout121, reserved: reserved)

        #expect(composed.entryCount == 0)
        guard case .unfixable(let reason)? = composed.statuses.first?.analysis.outcome else {
            Issue.record("expected the mod to be left out")
            return
        }
        #expect(reason.contains("game_patches.c:213"))
    }

    @Test func bytesThatDoNotFillAWordAreWrittenAsTheyAre() throws {
        let report = MergeReport(buildId: layout121.buildId,
                                 defaultPatches: [PatchEntry(address: 0x1001, hex: "AABB")!, PatchEntry(address: 0x1004, hex: "1F2003D5")!],
                                 codePatches: [], ignoredCode: [])

        let composed = try PatchComposer.compose(report: report, layout: layout121)

        #expect(composed.entryCount == 2)
        #expect(composed.pchtxt.contains("\n00001001 AABB\n00001004 1F2003D5\n"))
    }

    @Test func bytesPastTheEndOfTheAddressSpaceAreLeftOut() throws {
        let report = MergeReport(buildId: layout121.buildId, defaultPatches: [PatchEntry(address: 0xFFFF_FFFE, hex: "AABBCCDD")!],
                                 codePatches: [], ignoredCode: [])

        let composed = try PatchComposer.compose(report: report, layout: layout121)

        #expect(composed.entryCount == 1)
        #expect(composed.pchtxt.contains("\nfffffffe AABB\n"))
    }
}
