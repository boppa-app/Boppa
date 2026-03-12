import SwiftUI

struct MinifiedBrowserToolbarView: View {
    let host: String
    let isLoading: Bool

    var body: some View {
        HStack {
            Spacer()

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
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.systemGray6))
            .cornerRadius(8)

            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

#Preview {
    MinifiedBrowserToolbarView(host: "google.com", isLoading: false)
}
