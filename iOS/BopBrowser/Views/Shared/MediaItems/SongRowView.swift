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
                Text(self.song.artist)
                    .font(.caption)
                    .foregroundColor(Color(.systemGray))
                    .lineLimit(1)
            }
            Spacer()
            Text(self.song.formattedDuration)
                .font(.caption)
                .foregroundColor(Color(.systemGray))
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}
