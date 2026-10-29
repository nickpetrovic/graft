import SwiftUI
import Testing
@testable import GraftApp

struct GameStatusTests {
    @Test func theStatusCountsWhatIsLeftToFix() {
        #expect(GameStatus(problems: [], supported: true).title == "Ready")
        #expect(GameStatus(problems: ["a"], supported: true).title == "1 thing to fix")
        #expect(GameStatus(problems: ["a", "b"], supported: true).title == "2 things to fix")
        #expect(GameStatus(problems: ["a"], supported: false).title == "Not supported yet")
        #expect(GameStatus(problems: [], supported: true).color == .green)
        #expect(GameStatus(problems: ["a"], supported: true).color == .orange)
    }
}
