import Foundation
import Testing
@testable import ModKit

struct ModSummaryTests {
    @Test func everyModGetsALineSayingWhatItChanges() {
        let buildId = layout121.buildId
        #expect(mod("m", dataFiles: 2325).summaryLine(buildId: buildId) == "2,325 game files")
        #expect(mod("m", dataFiles: 1).summaryLine(buildId: buildId) == "1 game file")
        #expect(mod("m", dataFiles: 0, codePatchBuilds: [buildId]).summaryLine(buildId: buildId) == "Game code")
        #expect(mod("m", dataFiles: 3580, textFiles: 3, codePatchBuilds: [buildId]).summaryLine(buildId: buildId) == "Game code and 3,583 files")
        #expect(mod("m", dataFiles: 0, codePatchBuilds: ["other"]).summaryLine(buildId: buildId) == "")
        #expect(mod("m", dataFiles: 0, codePatchBuilds: ["other"]).contentSummary(buildId: nil) == "Game code")
    }

    @Test func theCreditLeavesOutTheDefaultVersion() {
        #expect(mod("m", version: "2.0.0", author: "WarioSnap").summaryLine(buildId: nil) == "Version 2.0.0 by WarioSnap · 1 game file")
        #expect(mod("m", version: "1.0.0", author: "WarioSnap").credit == "By WarioSnap")
        #expect(mod("m", version: "2.0.0").credit == "Version 2.0.0")
        #expect(mod("m").credit == nil)
    }

    @Test func aModWithoutANameIsCalledUnnamed() {
        #expect(mod("m", name: "").displayName == "Unnamed mod")
        #expect(mod("m", name: "Hyrule").displayName == "Hyrule")
    }
}
