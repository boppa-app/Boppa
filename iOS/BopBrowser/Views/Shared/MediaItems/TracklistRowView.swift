import SwiftData
import SwiftUI

struct TracklistRow: View {
    @Environment(\.modelContext) private var modelContext

    let tracklist: Tracklist
    var showMediaSourceIcon: Bool = false

    private var albumPlaceholder: String {
        if #available(iOS 26.0, *) {
            return "music.note.square.stack.fill"
        } else {
            return "square.stack.fill"
        }
    }

    private var placeholder: String {
        switch self.tracklist.tracklistType {
        case .album:
            return self.albumPlaceholder
        default:
            return "music.note.list"
        }
    }

    private var resolvedMediaSource: MediaSource? {
        guard self.showMediaSourceIcon else { return nil }
        let mediaSourceId = self.tracklist.mediaSourceId
        let descriptor = FetchDescriptor<MediaSource>(
            predicate: #Predicate { $0.id == mediaSourceId }
        )
        return try? self.modelContext.fetch(descriptor).first
    }

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(url: self.tracklist.artworkUrl, placeholder: self.placeholder, size: 72)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(self.tracklist.title)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                if let subtitle = self.tracklist.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(Color(.systemGray))
                        .lineLimit(1)
                }
            }
            Spacer()
            if let mediaSource = self.resolvedMediaSource {
                self.mediaSourceIcon(mediaSource)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func mediaSourceIcon(_ mediaSource: MediaSource) -> some View {
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
