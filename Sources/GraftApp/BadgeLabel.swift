import ModKit
import SwiftUI

struct BadgeLabel: View {
    let badge: ModBadge

    var body: some View {
        BadgeCapsule(systemImage: badge.systemImage, title: badge.title, color: badge.color)
            .help(badge.help)
            .accessibilityElement(children: .combine)
    }
}

struct BadgeCapsule: View {
    let systemImage: String
    let title: String
    let color: Color
    @ScaledMetric(relativeTo: .callout) private var contentHeight: CGFloat = 16

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .foregroundStyle(color)
            Text(title)
                .foregroundStyle(.primary)
        }
        .font(.callout.weight(.semibold))
        .frame(height: contentHeight)
        .padding(.horizontal, 9)
        .padding(.vertical, 3)
        .background(color.opacity(0.16), in: Capsule())
    }
}
