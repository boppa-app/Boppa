import SwiftUI

struct SongRow: View {
    let song: Song

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(url: self.song.artworkUrl, placeholder: "music.note")
            VStack(alignment: .leading, spacing: 4) {
                Text(self.song.title)
                    .font(.body)
                    .foregroundColor(.white)
                    .lineLimit(1)
                if let artist = self.song.artist {
                    Text(artist)
                        .font(.caption)
                        .foregroundColor(Color(.systemGray))
                        .lineLimit(1)
                }
            }
            Spacer()
            if let duration = self.song.formattedDuration {
                Text(duration)
                    .font(.caption)
                    .foregroundColor(Color(.systemGray))
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}
