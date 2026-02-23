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
                Text(self.playlist.user)
                    .font(.caption)
                    .foregroundColor(Color(.systemGray))
                    .lineLimit(1)
            }
            Spacer()
            Text(self.playlist.formattedTrackCount)
                .font(.caption)
                .foregroundColor(Color(.systemGray))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}
