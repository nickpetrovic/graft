import Foundation
import Testing
@testable import ModKit

struct HexTests {
    @Test func hexNumbersMayHaveAPrefixAndSpaces() {
        #expect(UInt32(hex: "0x472c000") == 0x472c000)
        #expect(UInt32(hex: " 0X1F ") == 0x1f)
        #expect(UInt64(hex: "ff") == 0xff)
        #expect(UInt32(hex: "zz") == nil)
        #expect(UInt8(hex: "100") == nil)
    }
}
