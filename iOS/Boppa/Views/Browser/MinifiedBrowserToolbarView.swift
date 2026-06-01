import SwiftUI

struct MinifiedBrowserToolbarView: View {
    let host: String
    let isLoading: Bool
    var onClose: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 8))
                    .foregroundColor(Color(.systemGray))

                Text(self.host)
                    .font(.caption2)
                    .foregroundColor(Color(.systemGray))
                    .lineLimit(1)

                if self.isLoading {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 10, height: 10)
                        .accessibilityLabel("Loading")
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .accessibilityLabel(self.host)
            .accessibilityHint("Tap to show browser controls")
            .accessibilityAddTraits(.isButton)

            Button {
                self.onClose?()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.red)
            }
            .accessibilityLabel("Close Page")
            .accessibilityHint("Close the current web page")
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .contentShape(Rectangle())
    }
}

#Preview {
    MinifiedBrowserToolbarView(host: "google.com", isLoading: false)
}
