import SwiftUI

struct InfoButton<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    @ViewState private var showing = false

    var body: some View {
        Button {
            showing.toggle()
        } label: {
            Image(systemName: "info.circle")
        }
        .buttonStyle(.borderless)
        .help(title)
        .accessibilityLabel(title)
        .popover(isPresented: $showing, arrowEdge: .leading) {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.headline)
                content()
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(width: 320, alignment: .leading)
        }
    }
}
