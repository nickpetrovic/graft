import Foundation
import Testing
@testable import ModKit

struct ModelsTests {
    @Test func patchBytesAreReadFromWholeHexBytes() throws {
        #expect(PatchEntry(address: 0x10, hex: "1F2003d5")?.data == [0x1F, 0x20, 0x03, 0xD5])
        #expect(PatchEntry(address: 0x10, hex: "ABC") == nil)
        #expect(PatchEntry(address: 0x10, hex: "ZZ") == nil)
        let decoded = try JSONDecoder().decode(PatchEntry.self, from: Data(#"{"address": 4096, "bytes": "C0035FD6"}"#.utf8))
        #expect(decoded == PatchEntry(address: 0x1000, data: [0xC0, 0x03, 0x5F, 0xD6]))
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(PatchEntry.self, from: Data(#"{"address": 1, "bytes": "F"}"#.utf8)) }
    }

    @Test func optionGroupTypesSayHowManyChoicesTheyTake() {
        #expect(optionGroup("g", .multi, []).allowsMultiple)
        #expect(optionGroup("g", .multiRequired, []).isRequired)
        #expect(!optionGroup("g", .single, []).allowsMultiple)
        #expect(!optionGroup("g", .single, []).isRequired)
        #expect(optionGroup("g", .singleRequired, []).isRequired)
    }

    @Test func theSelectedOptionsAreListedByGroupName() {
        let mod = mod("m", groups: [optionGroup("FPS", .singleRequired, ["30", "60"], selected: ["60"]), optionGroup("Extras", .multi, ["Hats"])])
        #expect(mod.selectedOptions == ["FPS": ["60"], "Extras": []])
        #expect(mod.hasOptions)
    }
}
