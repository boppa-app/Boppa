import SwiftUI

struct MediaSourceRow: View {
    let source: MediaSource

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: source.iconSystemName)
                .font(.title3)
                .foregroundStyle(.accent)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(source.mediaSourceUrl)
                    .font(.body)

                Text(source.mediaSourceUrl)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}
