import AppKit
import ModKit
import SwiftUI

struct PathRow: View {
    let title: String
    let path: String
    let found: Bool
    let kind: GameDefinition.FileSetting.Kind
    let summary: String
    let detail: String
    var problem: String?
    let choose: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(title)
                InfoButton(title: title) {
                    Text(summary)
                    Text(detail)
                }
                Spacer(minLength: 8)
                Button("Choose…") {
                    if let chosen = FilePicker.choose(kind, startingAt: path) { choose(chosen) }
                }
                .controlSize(.small)
            }
            HStack(spacing: 5) {
                Image(systemName: found ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(found ? .green : .red)
                    .accessibilityLabel(found ? "Found" : "Not found")
                Text(path.isEmpty ? "Not set" : (path as NSString).abbreviatingWithTildeInPath)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.secondary)
            }
            .font(.callout)
            .contentShape(Rectangle())
            .help(path.isEmpty ? "Not set" : path)
            if let problem {
                Text(problem)
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 2)
    }
}
