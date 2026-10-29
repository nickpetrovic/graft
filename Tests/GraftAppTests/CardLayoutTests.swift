import CoreGraphics
import Testing
@testable import GraftApp

struct CardLayoutTests {
    let layout = CardLayout(frames: [CGRect(x: 0, y: 0, width: 100, height: 60),
                                     CGRect(x: 0, y: 68, width: 100, height: 80),
                                     CGRect(x: 0, y: 156, width: 100, height: 60)], spacing: 8)

    @Test func aCardTakesTheNextSlotOnceItsCenterPassesTheNeighborsCenter() {
        #expect(layout.target(of: 0, top: 40) == 0)
        #expect(layout.target(of: 0, top: 80) == 1)
        #expect(layout.target(of: 0, top: 200) == 2)
        #expect(layout.target(of: 2, top: 0) == 0)
    }

    @Test func theCardsInBetweenMoveByTheDraggedCardsHeightAndSpacing() {
        #expect(layout.shift(of: 1, from: 0, target: 1) == -68)
        #expect(layout.shift(of: 2, from: 0, target: 1) == 0)
        #expect(layout.shift(of: 0, from: 2, target: 0) == 68)
        #expect(layout.shift(of: 1, from: 2, target: 0) == 68)
    }

    @Test func theDroppedCardLandsWhereItsNewSlotStarts() {
        #expect(layout.landingTop(of: 0, target: 1) == 88)
        #expect(layout.landingTop(of: 0, target: 2) == 156)
        #expect(layout.landingTop(of: 2, target: 0) == 0)
        #expect(layout.landingTop(of: 1, target: 1) == 68)
    }

    @Test func numbersShowWhereEachCardWillLandWhileDragging() {
        #expect((0..<4).map { CardLayout.displayPosition(of: $0, from: 1, target: 3) } == [0, 3, 1, 2])
        #expect((0..<4).map { CardLayout.displayPosition(of: $0, from: 3, target: 0) } == [1, 2, 3, 0])
        #expect((0..<4).map { CardLayout.displayPosition(of: $0, from: 2, target: 2) } == [0, 1, 2, 3])
    }
}
