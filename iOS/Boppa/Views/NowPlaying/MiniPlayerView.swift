import SwiftUI

struct MiniPlayerView: View {
    @Binding var showNowPlaying: Bool

    private static let artworkSize: CGFloat = 48
    private static let verticalPadding: CGFloat = 6
    private static let progressBarHeight: CGFloat = 3

    static let height: CGFloat = artworkSize + verticalPadding * 2 + progressBarHeight

    private var playbackService: PlaybackService {
        PlaybackService.shared
    }

    var body: some View {
        self.playerContent
    }

    private var playerContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                self.artwork
                self.trackInfo
                Spacer()
                self.playPauseButton
            }
            .padding(.horizontal, 16)
            .padding(.vertical, Self.verticalPadding)

            self.progressBar
        }
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            self.showNowPlaying = true
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(self.playbackService.currentTrack.map {
            [$0.title, $0.subtitle].compactMap { $0 }.joined(separator: ", ")
        } ?? "Now Playing")
        .accessibilityHint("Open Now Playing")
        .accessibilityAddTraits(.isButton)
    }

    private var progressBar: some View {
        GeometryReader { geometry in
            let progress = self.playbackService.duration > 0
                ? self.playbackService.currentTime / self.playbackService.duration
                : 0

            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.purp.opacity(0.3))
                Rectangle()
                    .fill(Color.purp)
                    .frame(width: geometry.size.width * CGFloat(min(progress, 1.0)))
            }
        }
        .frame(height: Self.progressBarHeight)
    }

    private var artwork: some View {
        ArtworkView(
            lowResUrl: self.playbackService.currentTrack?.resolvedLowResArtworkUrl,
            highResUrl: self.playbackService.currentTrack?.resolvedHighResArtworkUrl,
            placeholder: "music.note",
            size: Self.artworkSize,
            placeholderBackground: .charcoal
        )
    }

    private var trackInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            MarqueeText(
                self.playbackService.currentTrack?.title ?? "",
                font: .subheadline,
                fontWeight: .medium,
                foregroundColor: .white,
                uniqueId: self.playbackService.currentTrack?.id.uuidString,
                visible: !self.showNowPlaying
            )

            if let subtitle = self.playbackService.currentTrack?.subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(Color(.systemGray))
                    .lineLimit(1)
            }
        }
    }

    private var playPauseButton: some View {
        Group {
            if self.playbackService.isLoading {
                SpinnerView(lineWidth: 3)
                    .frame(width: 20, height: 20)
                    .frame(width: 32, height: 32)
                    .accessibilityLabel("Loading")
            } else {
                Button {
                    self.playbackService.togglePlayPause()
                } label: {
                    Image(systemName: self.playbackService.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(self.playbackService.isPlaying ? "Pause" : "Play")
                .accessibilityHint(self.playbackService
                    .isPlaying ? "Pause playback" : "Resume playback")
            }
        }
    }
}

#Preview {
    ZStack(alignment: .bottom) {
        Color.black.ignoresSafeArea()
        MiniPlayerView(showNowPlaying: .constant(false))
    }
}
