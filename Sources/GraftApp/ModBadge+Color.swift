import ModKit
import SwiftUI

extension ModBadge {
    var color: Color {
        switch kind {
        case .fixed: .green
        case .partial: .orange
        case .wrongVersion, .wontWork: .red
        }
    }

    var systemImage: String {
        switch kind {
        case .fixed: "checkmark.seal.fill"
        case .partial: "circle.lefthalf.filled"
        case .wrongVersion: "clock.badge.xmark.fill"
        case .wontWork: "xmark.octagon.fill"
        }
    }
}
