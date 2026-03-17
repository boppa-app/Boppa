import SwiftUI

struct NowPlayingView: View {
    @Environment(\.dismiss) private var dismiss

    var viewModel: NowPlayingViewModel

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
            if self.viewModel.showQueue {
                QueueView()
            }
        }
    }

    private var artworkSection: some View {
        Group {
            if let url = self.viewModel.artworkURL {
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
            Text(self.viewModel.trackTitle)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .lineLimit(1)

            Text(self.viewModel.trackArtist)
                .font(.body)
                .foregroundColor(Color(.systemGray))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var seekBar: some View {
        VStack(spacing: 6) {
            SeekSlider(
                value: self.viewModel.displayCurrentTime,
                minimum: 0,
                maximum: self.viewModel.seekMaximum,
                onEditingChanged: { editing, newValue in
                    self.viewModel.handleSeekEditingChanged(editing: editing, newValue: newValue)
                },
                onValueChanged: { newValue in
                    self.viewModel.handleSeekValueChanged(newValue: newValue)
                }
            )
            .frame(height: 30)

            HStack {
                Text(self.viewModel.formattedCurrentTime)
                    .font(.caption)
                    .foregroundColor(Color(.systemGray))
                    .monospacedDigit()
                Spacer()
                Text(self.viewModel.formattedDuration)
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
                    self.viewModel.previous()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                        .frame(width: 48, height: 48)
                }
                .disabled(!self.viewModel.canGoBack)

                if self.viewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(2.5)
                        .frame(width: 48, height: 48)
                } else {
                    Button {
                        self.viewModel.togglePlayPause()
                    } label: {
                        Image(systemName: self.viewModel.playPauseIconName)
                            .font(.system(size: 56))
                            .foregroundColor(.white)
                            .frame(width: 48, height: 48)
                    }
                }

                Button {
                    self.viewModel.next()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                        .frame(width: 48, height: 48)
                }
                .disabled(!self.viewModel.canSkipForward)
            }

            Spacer()

            Button {
                self.viewModel.cycleRepeatMode()
            } label: {
                Image(systemName: self.viewModel.repeatIconName)
                    .font(.system(size: 18))
                    .foregroundColor(self.viewModel.isRepeatActive ? Color.purp : Color(.systemGray))
                    .frame(width: 36, height: 36)
            }
        }
    }

    private var queueToggleButton: some View {
        HStack {
            Button {
                self.viewModel.openInBrowser(dismiss: self.dismiss)
            } label: {
                Image(systemName: "safari")
                    .font(.system(size: 20))
                    // TODO: dont use gray for no URL because its confusing, potentially cross out browser with X or dont show icon (?)
                    .foregroundColor(self.viewModel.hasSongUrl ? Color.purp : Color(.systemGray))
                    .frame(width: 36, height: 36)
            }
            .disabled(!self.viewModel.hasSongUrl)

            Spacer()

            Button {
                self.viewModel.toggleQueue()
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 20))
                    .foregroundColor(self.viewModel.showQueue ? Color.purp : Color(.systemGray))
                    .frame(width: 36, height: 36)
            }
        }
    }
}

#Preview {
    NowPlayingView(viewModel: NowPlayingViewModel())
        .preferredColorScheme(.dark)
}
