import SwiftUI

struct AlbumRow: View {
    let album: Album

    private var albumPlaceholder: String {
        if #available(iOS 26.0, *) {
            return "music.note.square.stack.fill"
        } else {
            return "square.stack.fill"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(url: self.album.artworkUrl, placeholder: self.albumPlaceholder, size: 72)
            VStack(alignment: .leading, spacing: 4) {
                Text(self.album.title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)
                if let subtitle = self.album.subtitle {
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
