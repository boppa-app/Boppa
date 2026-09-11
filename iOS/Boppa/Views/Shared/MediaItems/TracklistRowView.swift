import SwiftUI

struct TracklistRow: View {
    let tracklist: Tracklist
    var showMediaSourceIcon: Bool = false
    var showMediaSourceDivider: Bool = false
    var showMediaSourceReveal: Bool = false
    var showChevron: Bool = false
    var isMediaSourceEnabled: Bool = true
    var artworkSize: CGFloat = 72
    var preferLowResArtwork: Bool? = nil
    var placeholderBackground: Color? = nil
    var mediaSourceRevealBackgroundColor: Color = .init(.black)
    var isSelected: Bool = false
    var revealInfo: MediaSourceRevealInfo?

    private var resolvedPreferLowResArtwork: Bool {
        self.preferLowResArtwork ?? (self.tracklist.tracklistType == .album)
    }

    @ViewBuilder
    private var subtitleView: some View {
        if let subtitle = tracklist.subtitle {
            if self.tracklist.tracklistType == .album, let year = tracklist.year {
                (
                    Text(subtitle).foregroundColor(Color(.systemGray))
                        + Text(" | ").foregroundColor(Color(.systemGray6))
                        + Text(verbatim: "\(year)").foregroundColor(Color(.systemGray3))
                )
                .font(.subheadline)
                .lineLimit(1)
            } else {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(Color(.systemGray))
                    .lineLimit(1)
            }
        }
    }

    private var mediaSourceColor: Color? {
        guard self.showMediaSourceDivider else { return nil }
        if self.tracklist.mediaSourceId == "boppa.app" {
            return .purp
        }
        guard let info = self.revealInfo else { return nil }
        if let hex = info.highlightColor {
            return Color(hex: hex)
        }
        return Color.purp
    }

    private var mediaSourceRevealIcon: MediaSourceRevealIcon? {
        guard self.showMediaSourceReveal else { return nil }
        if self.tracklist.mediaSourceId == "boppa.app" {
            return .asset("Boppa")
        }
        return self.revealInfo?.iconSvg.map(MediaSourceRevealIcon.svg)
    }

    var body: some View {
        HStack(spacing: 12) {
            TracklistArtworkView(
                tracklist: self.tracklist,
                preferLowRes: self.resolvedPreferLowResArtwork,
                size: self.artworkSize,
                placeholderBackground: self.placeholderBackground,
                borderColor: self.mediaSourceColor,
                mediaSourceRevealIcon: self.mediaSourceRevealIcon,
                revealBackgroundColor: self.mediaSourceRevealBackgroundColor
            )
            .opacity(!self.isMediaSourceEnabled ? 0.3 : 1.0)
            if let mediaSourceColor = self.mediaSourceColor {
                Capsule()
                    .fill(mediaSourceColor)
                    .frame(width: 2, height: self.artworkSize * 0.7)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(self.tracklist.title)
                        .font(.headline)
                        .fontWeight(self.isSelected ? .bold : .regular)
                        .foregroundColor(self.isSelected ? .purp : .white)
                        .lineLimit(1)
                }
                self.subtitleView
            }
            .opacity(!self.isMediaSourceEnabled ? 0.3 : 1.0)
            Spacer()
            if self.showMediaSourceIcon, let info = self.revealInfo {
                self.mediaSourceIcon(info)
            }
            if self.showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.purp)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel([self.tracklist.title, self.tracklist.subtitle].compactMap { $0 }
            .joined(separator: ", "))
    }

    @ViewBuilder
    private func mediaSourceIcon(_ info: MediaSourceRevealInfo) -> some View {
        if let iconSvg = info.iconSvg {
            SVGImageView(svgString: iconSvg, size: 28)
                .frame(width: 28, height: 28)
                .opacity(0.5)
        } else {
            Image(systemName: "music.note")
                .font(.system(size: 20))
                .foregroundColor(.purp)
                .frame(width: 28, height: 28)
                .opacity(0.5)
        }
    }
}
