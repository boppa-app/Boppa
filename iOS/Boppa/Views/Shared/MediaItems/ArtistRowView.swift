import SwiftUI

struct ArtistRow: View {
    let artist: Artist
    var showChevron: Bool = false
    var showMediaSourceDivider: Bool = false
    var showMediaSourceReveal: Bool = false
    var mediaSourceRevealBackgroundColor: Color = .init(.black)
    var revealConfig: MediaSourceConfig?

    private let artworkSize: CGFloat = 48

    private var mediaSourceColor: Color? {
        guard self.showMediaSourceDivider else { return nil }
        if self.artist.mediaSourceId == "boppa.app" {
            return .purp
        }
        guard let config = self.revealConfig else { return nil }
        if let hex = config.highlightColor {
            return Color(hex: hex)
        }
        return Color.purp
    }

    private var mediaSourceRevealIcon: MediaSourceRevealIcon? {
        guard self.showMediaSourceReveal else { return nil }
        if self.artist.mediaSourceId == "boppa.app" {
            return .asset("Boppa")
        }
        return self.revealConfig?.iconSvg.map(MediaSourceRevealIcon.svg)
    }

    var body: some View {
        HStack(spacing: 12) {
            MediaSourceRevealArtwork(
                size: self.artworkSize,
                cornerRadius: self.artworkSize / 2,
                borderColor: self.mediaSourceColor,
                mediaSourceRevealIcon: self.mediaSourceRevealIcon,
                revealBackgroundColor: self.mediaSourceRevealBackgroundColor
            ) {
                ArtworkView(
                    lowResUrl: self.artist.lowResArtworkUrl,
                    highResUrl: self.artist.highResArtworkUrl,
                    placeholder: "person",
                    size: self.artworkSize,
                    isCircular: true
                )
            }
            if let mediaSourceColor = self.mediaSourceColor {
                Capsule()
                    .fill(mediaSourceColor)
                    .frame(width: 2, height: self.artworkSize * 0.7)
            }
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(self.artist.name)
    }
}
