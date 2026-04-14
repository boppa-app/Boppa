import SwiftUI

struct PlaylistRow: View {
    let playlist: Playlist

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(url: self.playlist.artworkUrl, placeholder: "music.note.list", size: 72)
            VStack(alignment: .leading, spacing: 4) {
                Text(self.playlist.title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)
                if let user = self.playlist.user {
                    Text(user)
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
