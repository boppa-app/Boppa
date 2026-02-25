import SwiftUI

struct MiniPlayerView: View {
    @Binding var showNowPlaying: Bool

    private var playbackService: PlaybackService {
        PlaybackService.shared
    }

    var body: some View {
        if self.playbackService.state.hasTrack {
            self.playerContent
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var playerContent: some View {
        VStack(spacing: 0) {
            self.progressBar

            HStack(spacing: 12) {
                self.artwork
                self.trackInfo
                Spacer()
                self.playPauseButton
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
        .background(Color.black)
        .contentShape(Rectangle())
        .onTapGesture {
            self.showNowPlaying = true
        }
    }

    private var progressBar: some View {
        GeometryReader { geometry in
            let progress = self.playbackService.state.duration > 0
                ? self.playbackService.state.currentTime / self.playbackService.state.duration
                : 0

            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color(.systemGray5))
                Rectangle()
                    .fill(Color.purp)
                    .frame(width: geometry.size.width * CGFloat(min(progress, 1.0)))
            }
        }
        .frame(height: 3)
    }

    private var artwork: some View {
        ArtworkView(
            url: self.playbackService.state.currentTrack?.artworkUrl,
            placeholder: "music.note"
        )
    }

    private var trackInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(self.playbackService.state.currentTrack?.title ?? "")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .lineLimit(1)

            if let artist = self.playbackService.state.currentTrack?.artist {
                Text(artist)
                    .font(.caption)
                    .foregroundColor(Color(.systemGray))
                    .lineLimit(1)
            }
        }
    }

    private var playPauseButton: some View {
        Group {
            if self.playbackService.state.isLoading {
                ProgressView()
                    .tint(.white)
                    .frame(width: 32, height: 32)
            } else {
                Button {
                    self.playbackService.togglePlayPause()
                } label: {
                    Image(systemName: self.playbackService.state.isPlaying ? "pause.fill" : "play.fill")
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
