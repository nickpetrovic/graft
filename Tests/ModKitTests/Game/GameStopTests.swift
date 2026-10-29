import Foundation
import Testing
@testable import ModKit

struct GameStopTests {
    @Test func theReasonAndHintAreReadFromTheLog() {
        let asleep = GameStop.parse("[totk] window drawable 3456x1944 (scale 2)\n[totk] FAIL: native display link initialization\n", game: totk)
        #expect(asleep == GameStop(reason: "native display link initialization", hint: .wakeDisplay))
        #expect(GameStop.parse("[totk] FAIL: TOTK_PCHTXT build id does not match main\n", game: totk)?.hint == .rebuildForCodeMods)
        #expect(GameStop.parse("[totk] FAIL: RomFS overlay entry changed size\n", game: totk)?.hint == .reinstallMods)
        #expect(GameStop.parse("[totk] FAIL: something else\n", game: totk) == GameStop(reason: "something else", hint: nil))
    }

    @Test func aLogWithoutAFailureHasNoStop() {
        #expect(GameStop.parse("[totk] first presented frame\n", game: totk) == nil)
        #expect(GameStop.parse("[ot0] FAIL: native display link initialization\n", game: totk) == nil)
    }
}
