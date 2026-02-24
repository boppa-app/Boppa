import SwiftUI

struct AlbumRow: View {
    let album: Album

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(url: self.album.artworkUrl, placeholder: "square.stack")
            VStack(alignment: .leading, spacing: 4) {
                Text(self.album.title)
                    .font(.body)
                    .foregroundColor(.white)
                    .lineLimit(1)
                if let artist = self.album.artist {
                    Text(artist)
                        .font(.caption)
                        .foregroundColor(Color(.systemGray))
                        .lineLimit(1)
                }
            }
            Spacer()
            if let trackCount = self.album.formattedTrackCount {
                Text(trackCount)
                    .font(.caption)
                    .foregroundColor(Color(.systemGray))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}
