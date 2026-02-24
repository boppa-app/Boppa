import SwiftUI

struct PlaylistRow: View {
    let playlist: Playlist

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(url: self.playlist.artworkUrl, placeholder: "music.note.list")
            VStack(alignment: .leading, spacing: 4) {
                Text(self.playlist.title)
                    .font(.body)
                    .foregroundColor(.white)
                    .lineLimit(1)
                if let user = self.playlist.user {
                    Text(user)
                        .font(.caption)
                        .foregroundColor(Color(.systemGray))
                        .lineLimit(1)
                }
            }
            Spacer()
            if let trackCount = self.playlist.formattedTrackCount {
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
