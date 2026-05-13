import SwiftUI

struct ArtistRow: View {
    let artist: Artist
    var showChevron: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(url: self.artist.artworkUrl, placeholder: "person", isCircular: true)
            Text(self.artist.name)
                .font(.body)
                .foregroundColor(.white)
                .lineLimit(1)
            Spacer()
            if self.showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.purp)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}
