import SwiftUI

// TODO: If source is deleted which == playback source then stop playing (skip to next song not from that source) and clear songs with that source from the queue.

struct MiniPlayerView: View {
    @Binding var showNowPlaying: Bool

    private var playbackService: PlaybackService {
        PlaybackService.shared
    }

    var body: some View {
        if self.playbackService.hasTrack {
            self.playerContent
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
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
            .padding(.vertical, 6)

            self.progressBar
        }
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            self.showNowPlaying = true
        }
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
        .frame(height: 3)
    }

    private var artwork: some View {
        ArtworkView(
            url: self.playbackService.currentTrack?.artworkUrl,
            placeholder: "music.note"
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

            if let artist = self.playbackService.currentTrack?.artist {
                Text(artist)
                    .font(.caption)
                    .foregroundColor(Color(.systemGray))
                    .lineLimit(1)
            }
        }
    }

    private var playPauseButton: some View {
        Group {
            if self.playbackService.isLoading {
                ProgressView()
                    .tint(.white)
                    .frame(width: 32, height: 32)
            } else {
                Button {
                    self.playbackService.togglePlayPause()
                } label: {
                    Image(systemName: self.playbackService.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                }
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
