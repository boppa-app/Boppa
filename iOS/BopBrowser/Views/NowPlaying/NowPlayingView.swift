import SwiftUI

struct NowPlayingView: View {
    @Environment(\.dismiss) private var dismiss

    private var playbackService: PlaybackService {
        PlaybackService.shared
    }

    private var queueManager: SongQueueManager {
        SongQueueManager.shared
    }

    @State private var isSeeking = false
    @State private var seekValue: Double = 0
    @State private var showQueue = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            self.mediaDisplaySection
            Spacer().frame(height: 24)
            self.seekBar
            Spacer().frame(height: 24)
            self.transportControls
            Spacer().frame(height: 12)
            self.queueToggleButton
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .preferredColorScheme(.dark)
    }

    private var mediaDisplaySection: some View {
        VStack(spacing: 0) {
            self.artworkSection
            Spacer().frame(height: 32)
            self.trackInfoSection
        }
        .overlay {
            if self.showQueue {
                QueueView()
            }
        }
    }

    private var artworkSection: some View {
        Group {
            if let artworkUrl = self.playbackService.currentTrack?.artworkUrl,
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
            Text(self.playbackService.currentTrack?.title ?? "Not Playing")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .lineLimit(1)

            Text(self.playbackService.currentTrack?.artist ?? "")
                .font(.body)
                .foregroundColor(Color(.systemGray))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var seekBar: some View {
        VStack(spacing: 6) {
            SeekSlider(
                value: self.isSeeking ? self.seekValue : self.playbackService.currentTime,
                minimum: 0,
                maximum: max(self.playbackService.duration, 1),
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
                Text(Song.formatTime(seconds: self.isSeeking ? self.seekValue : self.playbackService.currentTime))
                    .font(.caption)
                    .foregroundColor(Color(.systemGray))
                    .monospacedDigit()
                Spacer()
                Text(Song.formatTime(seconds: self.playbackService.duration))
                    .font(.caption)
                    .foregroundColor(Color(.systemGray))
                    .monospacedDigit()
            }
        }
    }

    private var transportControls: some View {
        HStack {
            Button {} label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 18))
                    .foregroundColor(Color(.systemGray))
                    .frame(width: 36, height: 36)
            }

            Spacer()

            HStack(spacing: 40) {
                Button {
                    self.playbackService.previous()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                        .frame(width: 48, height: 48)
                }
                .disabled(self.queueManager.queue.isEmpty)

                if self.playbackService.isLoading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(2.5)
                        .frame(width: 48, height: 48)
                } else {
                    Button {
                        self.playbackService.togglePlayPause()
                    } label: {
                        Image(systemName: self.playbackService.isPlaying ? "pause.fill" : "play.fill")
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
                .disabled(self.queueManager.queue.count <= 1)
            }

            Spacer()

            Button {
                self.queueManager.cycleRepeatMode()
            } label: {
                Image(systemName: self.repeatIconName)
                    .font(.system(size: 18))
                    .foregroundColor(self.queueManager.repeatMode != .off ? Color.purp : Color(.systemGray))
                    .frame(width: 36, height: 36)
            }
        }
    }

    private var repeatIconName: String {
        switch self.queueManager.repeatMode {
        case .off, .all:
            return "repeat"
        case .one:
            return "repeat.1"
        }
    }

    private var queueToggleButton: some View {
        HStack {
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    self.showQueue.toggle()
                }
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 20))
                    .foregroundColor(self.showQueue ? Color.purp : Color(.systemGray))
                    .frame(width: 36, height: 36)
            }
        }
    }
}

#Preview {
    NowPlayingView()
        .preferredColorScheme(.dark)
}
