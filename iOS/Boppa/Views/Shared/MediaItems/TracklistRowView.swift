import SwiftUI

struct TracklistRow: View {
    let tracklist: Tracklist
    var showMediaSourceIcon: Bool = false
    var showChevron: Bool = false
    var isMediaSourceEnabled: Bool = true
    var artworkSize: CGFloat = 72
    var preferLowResArtwork: Bool? = nil

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

    private var resolvedMediaSource: StoredMediaSource? {
        guard self.showMediaSourceIcon else { return nil }
        return MediaSourceStorageManager.shared.fetchOne(id: self.tracklist.mediaSourceId)
    }

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(
                lowResUrl: self.tracklist.lowResArtworkUrl,
                highResUrl: self.tracklist.highResArtworkUrl,
                preferLowRes: self.resolvedPreferLowResArtwork,
                tracklistType: self.tracklist.tracklistType,
                size: self.artworkSize
            )
            .opacity(!self.isMediaSourceEnabled ? 0.3 : 1.0)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(self.tracklist.title)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                self.subtitleView
            }
            .opacity(!self.isMediaSourceEnabled ? 0.3 : 1.0)
            Spacer()
            if let mediaSource = self.resolvedMediaSource {
                self.mediaSourceIcon(mediaSource)
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
        .accessibilityLabel([self.tracklist.title, self.tracklist.subtitle].compactMap { $0 }.joined(separator: ", "))
    }

    @ViewBuilder
    private func mediaSourceIcon(_ mediaSource: StoredMediaSource) -> some View {
        if let iconSvg = mediaSource.config.iconSvg {
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
