import Foundation
import Testing
@testable import ModKit

struct ReservedSiteTests {
    @Test func sitesAreReadFromThePortsScript() throws {
        let json = #"[{"label": "game_patches.c:213", "offset": "0x7ede80"}, {"label": "wide", "offset": "7ee000", "size": 8}]"#
        let sites = try JSONDecoder().decode([ReservedSite].self, from: Data(json.utf8))
        #expect(sites == [ReservedSite(label: "game_patches.c:213", offset: 0x7ede80, size: 4), ReservedSite(label: "wide", offset: 0x7ee000, size: 8)])
        #expect(throws: DecodingError.self) { try JSONDecoder().decode([ReservedSite].self, from: Data(#"[{"label": "x", "offset": "nowhere"}]"#.utf8)) }
    }

    @Test func overlapsCountOnlySharedBytes() {
        let site = ReservedSite(label: "x", offset: 0x100, size: 4)
        #expect(site.overlaps(address: 0x100, length: 4))
        #expect(site.overlaps(address: 0xfe, length: 4))
        #expect(site.overlaps(address: 0x103, length: 1))
        #expect(!site.overlaps(address: 0x104, length: 4))
        #expect(!site.overlaps(address: 0xfc, length: 4))
    }
}
