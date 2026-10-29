import SwiftUI

struct Banner<Actions: View>: View {
    let color: Color
    let systemImage: String
    let text: String
    @ViewBuilder let actions: () -> Actions

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(color)
            Text(text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
            HStack { actions() }
        }
        .font(.body)
        .padding(14)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
