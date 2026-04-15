import SwiftUI

struct TracklistRow: View {
    let tracklist: Tracklist

    private var albumPlaceholder: String {
        if #available(iOS 26.0, *) {
            return "music.note.square.stack.fill"
        } else {
            return "square.stack.fill"
        }
    }

    private var placeholder: String {
        switch self.tracklist.tracklistType {
        case .album:
            return self.albumPlaceholder
        default:
            return "music.note.list"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(url: self.tracklist.artworkUrl, placeholder: self.placeholder, size: 72)
            VStack(alignment: .leading, spacing: 4) {
                Text(self.tracklist.title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)
                if let subtitle = self.tracklist.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(Color(.systemGray))
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}
