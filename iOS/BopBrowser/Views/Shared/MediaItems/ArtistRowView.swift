import SwiftUI

struct ArtistRow: View {
    let artist: Artist

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(url: self.artist.artworkUrl, placeholder: "person")
            Text(self.artist.name)
                .font(.body)
                .foregroundColor(.white)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}
