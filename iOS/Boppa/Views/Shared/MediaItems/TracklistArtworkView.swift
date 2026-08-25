import SwiftUI

struct TracklistArtworkView: View {
    let tracklist: Tracklist
    var preferLowRes: Bool = true
    var size: CGFloat = 48
    var cornerRadius: CGFloat?
    var placeholderBackground: Color? = nil
    var borderColor: Color? = nil
    var mediaSourceIconSvg: String? = nil
    var revealBackgroundColor: Color = .init(.systemGray5)

    @State private var isRevealingMediaSource = false
    @State private var revealTask: Task<Void, Never>?

    private var hasStoredArtwork: Bool {
        !(self.tracklist.lowResArtworkUrl ?? "").isEmpty
            || !(self.tracklist.highResArtworkUrl ?? "").isEmpty
    }

    private var resolvedCornerRadius: CGFloat {
        self.cornerRadius ?? 6
    }

    @ViewBuilder
    private var artworkContent: some View {
        if self.tracklist.tracklistType == .likes || self.hasStoredArtwork {
            ArtworkView(
                lowResUrl: self.tracklist.lowResArtworkUrl,
                highResUrl: self.tracklist.highResArtworkUrl,
                preferLowRes: self.preferLowRes,
                tracklistType: self.tracklist.tracklistType,
                size: self.size,
                cornerRadius: self.cornerRadius,
                placeholderBackground: self.placeholderBackground,
                borderColor: self.borderColor
            )
        } else {
            ComposedTracklistArtworkView(
                mediaId: self.tracklist.mediaId,
                mediaSourceId: self.tracklist.mediaSourceId,
                tracklistType: self.tracklist.tracklistType,
                size: self.size,
                cornerRadius: self.cornerRadius,
                placeholderBackground: self.placeholderBackground,
                borderColor: self.borderColor
            )
        }
    }

    private func mediaSourceRevealContent(svg: String) -> some View {
        RoundedRectangle(cornerRadius: self.resolvedCornerRadius)
            .fill(self.revealBackgroundColor)
            .frame(width: self.size, height: self.size)
            .overlay {
                SVGImageView(svgString: svg, size: self.size * 0.45)
            }
            .overlay {
                if let borderColor = self.borderColor {
                    RoundedRectangle(cornerRadius: self.resolvedCornerRadius)
                        .strokeBorder(borderColor, lineWidth: 2)
                }
            }
    }

    private func stackedContent(svg: String? = nil) -> some View {
        ZStack {
            self.artworkContent
                .opacity(self.isRevealingMediaSource ? 0 : 1)
            if let svg {
                self.mediaSourceRevealContent(svg: svg)
                    .opacity(self.isRevealingMediaSource ? 1 : 0)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: self.isRevealingMediaSource)
    }

    var body: some View {
        if let mediaSourceIconSvg = self.mediaSourceIconSvg {
            self.stackedContent(svg: mediaSourceIconSvg)
                .contentShape(Rectangle())
                .onTapGesture {
                    self.revealMediaSource()
                }
        } else {
            self.stackedContent()
        }
    }

    private func revealMediaSource() {
        self.revealTask?.cancel()
        self.isRevealingMediaSource = true
        self.revealTask = Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            self.isRevealingMediaSource = false
        }
    }
}

/// Resolves the composed artwork for a tracklist with none of its own: shows a single
/// image when fewer than 4 distinct track artworks were found, or a quadrant collage when
/// exactly 4 were collected.
private struct ComposedTracklistArtworkView: View {
    let mediaId: String
    let mediaSourceId: String
    let tracklistType: Tracklist.TracklistType
    let size: CGFloat
    let cornerRadius: CGFloat?
    let placeholderBackground: Color?
    let borderColor: Color?

    @State private var artwork: [TrackArtworkURLs]?
    @State private var refreshTick = 0

    private var resolvedCornerRadius: CGFloat {
        self.cornerRadius ?? 6
    }

    private var taskId: String {
        "\(self.mediaId)|\(self.mediaSourceId)|\(self.refreshTick)"
    }

    var body: some View {
        Group {
            if let artwork {
                if artwork.count >= 4 {
                    let quadrant = Array(artwork.prefix(4))
                    QuadrantOrFallbackArtworkView(
                        artwork: quadrant,
                        tracklistType: self.tracklistType,
                        size: self.size,
                        cornerRadius: self.cornerRadius,
                        placeholderBackground: self.placeholderBackground,
                        borderColor: self.borderColor
                    )
                    .id(quadrant.map { ($0.highResUrl ?? $0.lowResUrl) ?? "" }
                        .joined(separator: "|"))
                } else {
                    ArtworkView(
                        lowResUrl: artwork.first?.lowResUrl,
                        highResUrl: artwork.first?.highResUrl,
                        tracklistType: self.tracklistType,
                        size: self.size,
                        cornerRadius: self.cornerRadius,
                        placeholderBackground: self.placeholderBackground,
                        borderColor: self.borderColor
                    )
                }
            } else {
                ArtworkLoadingPlaceholder(size: self.size, cornerRadius: self.resolvedCornerRadius)
            }
        }
        .task(id: self.taskId) {
            let mediaId = self.mediaId
            let mediaSourceId = self.mediaSourceId
            let result = await Task.detached(priority: .userInitiated) {
                TracklistStorageManager.shared.resolveComposedArtwork(
                    mediaId: mediaId, mediaSourceId: mediaSourceId
                )
            }.value
            guard !Task.isCancelled else { return }
            self.artwork = result
        }
        .onReceive(NotificationCenter.default.publisher(for: .playlistMembershipChanged)) { _ in
            self.refreshTick += 1
        }
    }
}

private struct ArtworkLoadingPlaceholder: View {
    let size: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        ZStack {
            Color(.systemGray6)
            SpinnerView(tint: Color(.systemGray), lineWidth: max(self.size * 0.03, 2))
                .frame(width: max(self.size * 0.25, 16), height: max(self.size * 0.25, 16))
        }
        .frame(width: self.size, height: self.size)
        .cornerRadius(self.cornerRadius)
        .clipped()
    }
}

/// Preloads all 4 quadrant tiles and only reveals the collage once every tile has
/// successfully loaded its image. If any tile fails, falls back to a single artwork view
/// (using the first track's artwork) rather than showing a quadrant with a broken tile.
private struct QuadrantOrFallbackArtworkView: View {
    let artwork: [TrackArtworkURLs]
    let tracklistType: Tracklist.TracklistType
    let size: CGFloat
    let cornerRadius: CGFloat?
    let placeholderBackground: Color?
    let borderColor: Color?

    @State private var tileResults: [Int: Bool] = [:]

    private var resolvedCornerRadius: CGFloat {
        self.cornerRadius ?? 6
    }

    private var allLoaded: Bool {
        self.tileResults.count == self.artwork.count && self.tileResults.values.allSatisfy { $0 }
    }

    private var anyFailed: Bool {
        self.tileResults.values.contains(false)
    }

    private var tileSize: CGFloat {
        self.size / 2
    }

    var body: some View {
        if self.anyFailed {
            ArtworkView(
                lowResUrl: self.artwork.first?.lowResUrl,
                highResUrl: self.artwork.first?.highResUrl,
                tracklistType: self.tracklistType,
                size: self.size,
                cornerRadius: self.cornerRadius,
                placeholderBackground: self.placeholderBackground,
                borderColor: self.borderColor
            )
        } else {
            ZStack {
                if !self.allLoaded {
                    ArtworkLoadingPlaceholder(
                        size: self.size,
                        cornerRadius: self.resolvedCornerRadius
                    )
                }
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        self.tile(0)
                        self.tile(1)
                    }
                    HStack(spacing: 0) {
                        self.tile(2)
                        self.tile(3)
                    }
                }
                .frame(width: self.size, height: self.size)
                .cornerRadius(self.resolvedCornerRadius)
                .clipped()
                .opacity(self.allLoaded ? 1 : 0)
            }
            .overlay {
                if let borderColor = self.borderColor {
                    RoundedRectangle(cornerRadius: self.resolvedCornerRadius)
                        .strokeBorder(borderColor, lineWidth: 2)
                }
            }
        }
    }

    @ViewBuilder
    private func tile(_ index: Int) -> some View {
        let urls = self.artwork[index]
        ArtworkView(
            lowResUrl: urls.lowResUrl,
            highResUrl: urls.highResUrl,
            preferLowRes: false,
            placeholder: "music.note",
            size: self.tileSize,
            cornerRadius: 0,
            onLoadStateChange: { success in
                self.tileResults[index] = success
            }
        )
    }
}
