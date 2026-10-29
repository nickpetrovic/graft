import CoreGraphics

enum WindowSizing {
    static func mainWindow(on screen: CGRect) -> CGSize {
        CGSize(width: clamp(screen.width * 7 / 10, 760, min(1320, screen.width - 40)),
               height: clamp(screen.height * 0.75, 480, min(900, screen.height - 40)))
    }

    static let settingsContentHeight: CGFloat = 560

    static func settingsHeight(on screen: CGRect?) -> CGFloat {
        guard let screen else { return settingsContentHeight }
        return clamp(screen.height * 0.8, 420, settingsContentHeight)
    }

    private static func clamp(_ value: CGFloat, _ lower: CGFloat, _ upper: CGFloat) -> CGFloat {
        min(max(value, lower), max(lower, upper))
    }
}
