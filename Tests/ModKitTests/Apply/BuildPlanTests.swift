import Foundation
import Testing
@testable import ModKit

struct BuildPlanTests {
    func plan(code: String?, rewriter: Bool = false, supportsLaunch: Bool, built: String?,
              heap: String? = nil, appHeap: String? = nil, force: Bool = false) -> BuildPlan {
        BuildPlan.decide(codeDigest: code, needsRewriter: rewriter, appSupportsCodeAtLaunch: supportsLaunch,
                         builtCodeDigest: built, heapDigest: heap, appHeapDigest: appHeap, force: force)
    }

    @Test func codeModsLoadAtStartWithoutARebuildWhenTheAppSupportsIt() {
        #expect(plan(code: "new code", supportsLaunch: true, built: nil) == BuildPlan(codeAtLaunch: true, bakedCode: nil, reasons: []))
    }

    @Test func codeThatNeedsTheRewriterIsBuiltIn() {
        #expect(plan(code: "code", rewriter: true, supportsLaunch: true, built: nil)
                == BuildPlan(codeAtLaunch: false, bakedCode: "code", reasons: [.buildInCode]))
    }

    @Test func anAppWithoutLaunchSupportGetsTheCodeBuiltIn() {
        #expect(plan(code: "code", supportsLaunch: false, built: nil)
                == BuildPlan(codeAtLaunch: false, bakedCode: "code", reasons: [.buildInCode]))
    }

    @Test func codeThatIsAlreadyBuiltInStaysThereWithoutARebuild() {
        #expect(plan(code: "code", supportsLaunch: true, built: "code") == BuildPlan(codeAtLaunch: false, bakedCode: "code", reasons: []))
    }

    @Test func changedCodeMovesToLaunchAndTheBuiltInCopyIsRemoved() {
        #expect(plan(code: "new code", supportsLaunch: true, built: "old code")
                == BuildPlan(codeAtLaunch: true, bakedCode: nil, reasons: [.removeBuiltInCode]))
    }

    @Test func turningEveryModOffRemovesBuiltInCode() {
        #expect(plan(code: nil, supportsLaunch: false, built: "old code")
                == BuildPlan(codeAtLaunch: false, bakedCode: nil, reasons: [.removeBuiltInCode]))
    }

    @Test func memorySizeChangesAlwaysRebuild() {
        let changed = plan(code: nil, supportsLaunch: true, built: nil, heap: "mod heap")
        #expect(changed.reasons == [.memorySizes])
        #expect(changed.message == "Rebuilding the game app because the memory sizes changed")
    }

    @Test func aRequestedRebuildSaysSo() {
        #expect(plan(code: nil, supportsLaunch: true, built: nil, force: true).message == "Rebuilding the game app as you asked")
    }
}
