import SwiftUI

struct NowPlayingView: View {
    @Environment(\.dismiss) private var dismiss

    private var playbackService: PlaybackService {
        PlaybackService.shared
    }

    @State private var isSeeking = false
    @State private var seekValue: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            self.dragIndicator
            Spacer()
            self.artworkSection
            Spacer().frame(height: 32)
            self.trackInfoSection
            Spacer().frame(height: 24)
            self.seekBar
            Spacer().frame(height: 24)
            self.transportControls
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .preferredColorScheme(.dark)
    }

    private var dragIndicator: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color(.white))
            .frame(width: 40, height: 5)
            .padding(.top, 12)
    }

    private var artworkSection: some View {
        Group {
            if let artworkUrl = self.playbackService.state.currentTrack?.artworkUrl,
               let url = URL(string: artworkUrl)
            {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        self.artworkPlaceholder
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    @unknown default:
                        self.artworkPlaceholder
                    }
                }
            } else {
                self.artworkPlaceholder
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
    }

    private var artworkPlaceholder: some View {
        Image(systemName: "music.note")
            .font(.system(size: 60))
            .foregroundColor(Color(.systemGray3))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var trackInfoSection: some View {
        VStack(spacing: 6) {
            Text(self.playbackService.state.currentTrack?.title ?? "Not Playing")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .lineLimit(1)

            Text(self.playbackService.state.currentTrack?.artist ?? "")
                .font(.body)
                .foregroundColor(Color(.systemGray))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var seekBar: some View {
        VStack(spacing: 6) {
            SeekSlider(
                value: self.isSeeking ? self.seekValue : self.playbackService.state.currentTime,
                minimum: 0,
                maximum: max(self.playbackService.state.duration, 1),
                onEditingChanged: { editing, newValue in
                    if editing {
                        self.isSeeking = true
                        self.seekValue = newValue
                    } else {
                        self.playbackService.seek(to: newValue)
                        self.isSeeking = false
                    }
                },
                onValueChanged: { newValue in
                    self.seekValue = newValue
                }
            )
            .frame(height: 30)

            HStack {
                Text(Song.formatTime(seconds: self.isSeeking ? self.seekValue : self.playbackService.state.currentTime))
                    .font(.caption)
                    .foregroundColor(Color(.systemGray))
                    .monospacedDigit()
                Spacer()
                Text(Song.formatTime(seconds: self.playbackService.state.duration))
                    .font(.caption)
                    .foregroundColor(Color(.systemGray))
                    .monospacedDigit()
            }
        }
    }

    private var transportControls: some View {
        HStack(spacing: 40) {
            Button {
                self.playbackService.previous()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
            }
            .disabled(self.playbackService.state.queue.isEmpty)

            if self.playbackService.state.isLoading {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(2.5)
                    .frame(width: 48, height: 48)
            } else {
                Button {
                    self.playbackService.togglePlayPause()
                } label: {
                    Image(systemName: self.playbackService.state.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 56))
                        .foregroundColor(.white)
                        .frame(width: 48, height: 48)
                }
            }

            Button {
                self.playbackService.next()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
            }
            .disabled(self.playbackService.state.queue.count <= 1)
        }
    }
}

#Preview {
    NowPlayingView()
        .preferredColorScheme(.dark)
}
