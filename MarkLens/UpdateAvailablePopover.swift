#if os(macOS)
import SwiftUI

struct UpdateAvailablePopover: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    let release: AvailableRelease

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Update Available", systemImage: "arrow.down.circle.fill")
                .font(.headline)
                .foregroundStyle(Color.accentColor)

            Text("MarkLens \(release.displayVersion) is available.")

            if release.body
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty == false
            {
                Text(release.body)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(5)
            }

            HStack {
                Spacer()

                Button("Not Now") {
                    dismiss()
                }

                Button("View Release") {
                    dismiss()
                    openURL(release.htmlURL)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 340)
    }
}
#endif
