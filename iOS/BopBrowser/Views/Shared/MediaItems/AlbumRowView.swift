import SwiftUI

struct AlbumRow: View {
    let album: Album

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(url: self.album.artworkUrl, placeholder: "square.stack", size: 72)
            VStack(alignment: .leading, spacing: 4) {
                Text(self.album.title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)
                if let artist = self.album.artist {
                    Text(artist)
                        .font(.subheadline)
                        .foregroundColor(Color(.systemGray))
                        .lineLimit(1)
                }
            }
            Spacer()
            if let trackCount = self.album.formattedTrackCount {
                Text(trackCount)
                    .font(.subheadline)
                    .foregroundColor(Color(.systemGray))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}
