import AppKit
import SwiftUI
import Testing
@testable import GraftApp
@testable import ModKit

@MainActor
struct ModTitleTests {
    func height(_ view: some View) -> CGFloat {
        NSHostingView(rootView: view).fittingSize.height
    }

    @Test func aBadgeDoesNotChangeTheHeightOfAModsTitleLine() {
        let mod = InstalledMod(id: "a", name: "Teleport Anywhere", version: "", author: "", description: "", enabled: true, position: 0,
                               dataFiles: 0, textFiles: 0, subSdkFiles: 0, cheatFiles: 0, codePatchBuilds: ["0123"], optionGroups: [])
        let layout = GameLayout(version: "v143", displayVersion: "1.4.3", buildId: "ffff", dataStart: 0, imageEnd: 0, keyPageStart: 0)
        let badges = ModBadge.badges(for: mod, layout: layout, status: nil)
        let badge = BadgeCapsule(systemImage: "clock", title: "Not for 1.4.3", color: .red)

        #expect(badges.map(\.title) == ["Not for 1.4.3"])
        #expect(height(badge) > height(Text(mod.name).font(.title3.weight(.semibold))))
        for symbol in ["checkmark.seal.fill", "circle.lefthalf.filled", "clock.badge.xmark.fill", "xmark.octagon.fill"] {
            #expect(height(BadgeCapsule(systemImage: symbol, title: "X", color: .red)) == height(badge), "\(symbol)")
        }
        #expect(height(ModTitle(name: mod.name, badges: badges)) == height(ModTitle(name: mod.name, badges: [])))
    }
}
