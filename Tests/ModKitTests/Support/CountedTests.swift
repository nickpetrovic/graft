import Foundation
import Testing
@testable import ModKit

struct CountedTests {
    @Test func countsUseTheSingularForOne() {
        #expect(counted(1, "mod") == "1 mod")
        #expect(counted(0, "mod") == "0 mods")
        #expect(counted(3, "game file") == "3 game files")
    }
}
