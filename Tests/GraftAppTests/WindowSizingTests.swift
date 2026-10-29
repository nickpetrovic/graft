import CoreGraphics
import Testing
@testable import GraftApp

struct WindowSizingTests {
    @Test func mainWindowFollowsTheScreen() {
        #expect(WindowSizing.mainWindow(on: CGRect(x: 0, y: 0, width: 1728, height: 1084)) == CGSize(width: 1209.6, height: 813))
        #expect(WindowSizing.mainWindow(on: CGRect(x: 0, y: 0, width: 1440, height: 875)) == CGSize(width: 1008, height: 656.25))
        #expect(WindowSizing.mainWindow(on: CGRect(x: 0, y: 0, width: 3008, height: 1667)) == CGSize(width: 1320, height: 900))
    }

    @Test func settingsFitTheirContentWhenTheScreenAllows() {
        #expect(WindowSizing.settingsHeight(on: CGRect(x: 0, y: 0, width: 1728, height: 1084)) == 560)
        #expect(WindowSizing.settingsHeight(on: CGRect(x: 0, y: 0, width: 1280, height: 600)) == 480)
        #expect(WindowSizing.settingsHeight(on: nil) == 560)
    }
}
