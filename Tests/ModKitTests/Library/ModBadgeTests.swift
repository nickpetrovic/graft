import Foundation
import Testing
@testable import ModKit

struct ModBadgeTests {
    func titles(_ mod: InstalledMod, _ status: CodeStatus? = nil) -> [String] {
        ModBadge.badges(for: mod, layout: layout121, status: status).map(\.title)
    }

    @Test func dataOnlyModsHaveNoBadge() {
        #expect(titles(mod("m", dataFiles: 10)).isEmpty)
    }

    @Test func codeBadgesFollowTheCheckResult() {
        let code = mod("m", dataFiles: 0, codePatchBuilds: [layout121.buildId])
        #expect(titles(code).isEmpty)
        #expect(titles(code, .ok).isEmpty)
        #expect(titles(code, .fixed) == ["Fixed for Mac"])
        #expect(titles(code, .unfixable("reason")) == ["Won't work"])
        #expect(ModBadge.badges(for: code, layout: layout121, status: .unfixable("reason")).first?.help == "reason")
    }

    @Test func codeIsNotCalledTheWrongVersionWhenTheGameVersionIsUnknown() {
        let code = mod("m", dataFiles: 0, codePatchBuilds: ["other"])
        #expect(ModBadge.badges(for: code, layout: nil, status: nil).isEmpty)
    }

    @Test func otherVersionsAndUnloadablePartsAreNamed() {
        #expect(titles(mod("m", dataFiles: 0, codePatchBuilds: ["other"])) == ["Not for 1.2.1"])
        #expect(titles(mod("m", dataFiles: 1, codePatchBuilds: ["other"])) == ["Code not for 1.2.1"])
        #expect(titles(mod("m", dataFiles: 1, subSdkFiles: 1, cheatFiles: 1)) == ["Cheats not used", "Partly works"])
    }
}
