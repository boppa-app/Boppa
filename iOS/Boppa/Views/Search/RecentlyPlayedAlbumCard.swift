import SwiftUI

struct RecentlyPlayedAlbumCard: View {
    let tracklist: Tracklist
    let artworkUrls: [String?]
    let onTap: () -> Void

    var body: some View {
        Button(action: self.onTap) {
            VStack(alignment: .leading, spacing: 6) {
                StackedArtworkView(
                    artworkUrls: self.artworkUrls, size: RecentlyPlayedCard.artworkSize
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(self.tracklist.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(self.tracklist.subtitle ?? " ")
                        .font(.caption)
                        .foregroundColor(Color(.systemGray))
                        .lineLimit(1)
                }
                .frame(height: RecentlyPlayedCard.textBlockHeight, alignment: .top)
            }
            .frame(width: RecentlyPlayedCard.artworkSize, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            [self.tracklist.title, self.tracklist.subtitle].compactMap { $0 }.joined(
                separator: ", "
            )
        )
        .accessibilityHint("View album page for \(self.tracklist.title)")
        .accessibilityAddTraits(.isButton)
    }
}

private struct StackedArtworkView: View {
    let artworkUrls: [String?]
    let size: CGFloat

    private static let maxCovers = 3
    private static let step: CGFloat = 10

    private var covers: [String?] {
        Array(self.artworkUrls.prefix(Self.maxCovers).reversed())
    }

    private var tileSize: CGFloat {
        self.size - Self.step * CGFloat(self.covers.count - 1)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(self.covers.enumerated()), id: \.offset) { index, url in
                ArtworkView(url: url, tracklistType: .album, size: self.tileSize)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.black, lineWidth: index == 0 ? 0 : 2)
                    )
                    .offset(x: CGFloat(index) * Self.step, y: CGFloat(index) * Self.step)
            }
        }
        .frame(width: self.size, height: self.size, alignment: .topLeading)
    }
}
