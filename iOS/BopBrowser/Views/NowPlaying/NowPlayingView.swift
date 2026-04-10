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
        .opacity(self.viewModel.showQueue ? 0 : 1)
        .overlay {
            if self.viewModel.showQueue {
                QueueView()
            }
        }
    }

    private var artworkSection: some View {
        GeometryReader { geometry in
            ArtworkView(
                url: self.viewModel.currentTrack?.artworkUrl,
                placeholder: "music.note",
                size: geometry.size.width,
                cornerRadius: 12
            )
        }
        .aspectRatio(1, contentMode: .fit)
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
    }

    private var trackInfoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            MarqueeText(
                self.viewModel.trackTitle,
                font: .title3,
                fontWeight: .semibold,
                foregroundColor: .white,
                uniqueId: self.viewModel.currentTrack?.id
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(self.viewModel.trackSubtitle)
                .font(.body)
                .foregroundColor(Color(.systemGray))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                    .foregroundColor(self.viewModel.hasTrackUrl ? Color.purp : Color(.systemGray))
                    .frame(width: 36, height: 36)
            }
            .disabled(!self.viewModel.hasTrackUrl)

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
