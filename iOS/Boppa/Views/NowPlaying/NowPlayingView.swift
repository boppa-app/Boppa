import SwiftUI

struct NowPlayingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var trackForActions: Track?
    @State private var trackForAddToPlaylist: Track?

    var viewModel: NowPlayingViewModel
    var onArtistSelected: ((Artist) -> Void)?
    var onAlbumSelected: ((Tracklist) -> Void)?

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
        .background(Color.charcoal)
        .preferredColorScheme(.dark)
        .sheet(item: self.$trackForActions) { track in
            if let mediaSource = MediaSourceStorageManager.shared
                .fetchOne(id: track.mediaSourceId)
            {
                TrackActionsSheet(
                    track: track,
                    mediaSource: mediaSource,
                    isMediaSourceEnabled: track.isMediaSourceEnabled,
                    onArtistSelected: { artist in
                        self.dismiss()
                        self.onArtistSelected?(artist)
                    },
                    onAlbumSelected: { tracklist in
                        self.dismiss()
                        self.onAlbumSelected?(tracklist)
                    }
                )
            }
        }
        .sheet(item: self.$trackForAddToPlaylist) { track in
            AddToPlaylistSheet(track: track)
                .presentationDragIndicator(.visible)
                .presentationBackground(Color(.systemGray6))
        }
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
                lowResUrl: self.viewModel.currentTrack?.resolvedLowResArtworkUrl,
                highResUrl: self.viewModel.currentTrack?.resolvedHighResArtworkUrl,
                preferLowRes: false,
                placeholder: "music.note",
                size: geometry.size.width,
                cornerRadius: 12
            )
            .overlay(alignment: .topTrailing) {
                self.shareButton
                    .padding(.top, 30)
                    .padding(.trailing, 30)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .shadow(color: .black.opacity(self.viewModel.showQueue ? 0 : 0.6), radius: 30, y: 16)
    }

    private var trackInfoSection: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                MarqueeText(
                    self.viewModel.trackTitle,
                    font: .title3,
                    fontWeight: .semibold,
                    foregroundColor: .white,
                    uniqueId: self.viewModel.currentTrack?.id.uuidString
                )
                .accessibilityLabel(self.viewModel.trackTitle)

                Text(self.viewModel.trackSubtitle)
                    .font(.body)
                    .foregroundColor(Color(.systemGray))
                    .lineLimit(1)
                    .accessibilityLabel(self.viewModel.trackSubtitle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                self.trackForActions = self.viewModel.currentTrack
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("View actions for this track")

            Button {
                self.trackForAddToPlaylist = self.viewModel.currentTrack
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 22))
                    .foregroundColor(.purp)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .disabled(self.viewModel.currentTrack == nil)
            .accessibilityLabel("Add to Playlist")
            .accessibilityHint("Add this track to a playlist")

            Button {
                self.viewModel.toggleLike()
            } label: {
                Image(systemName: self.viewModel.isCurrentTrackLiked ? "heart.fill" : "heart")
                    .font(.system(size: 22))
                    .foregroundColor(self.viewModel
                        .isCurrentTrackLiked ? .purp : Color(.systemGray))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .disabled(self.viewModel.currentTrack == nil)
            .accessibilityLabel(self.viewModel.isCurrentTrackLiked ? "Unlike" : "Like")
            .accessibilityHint(self.viewModel
                .isCurrentTrackLiked ? "Remove from Likes" : "Add to Likes")
        }
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
                    .accessibilityLabel("Current time: \(self.viewModel.formattedCurrentTime)")
                Spacer()
                Text(self.viewModel.formattedDuration)
                    .font(.caption)
                    .foregroundColor(Color(.systemGray))
                    .monospacedDigit()
                    .accessibilityLabel("Duration: \(self.viewModel.formattedDuration)")
            }
        }
    }

    private var transportControls: some View {
        HStack {
            Button {
                self.viewModel.cycleShuffleMode()
            } label: {
                Image(systemName: self.viewModel
                    .shuffleMode == .radio ? "dot.radiowaves.left.and.right" : "shuffle")
                    .font(.system(size: 18))
                    .foregroundColor(self.viewModel.shuffleMode == .off ? Color(.systemGray) : Color
                        .purp)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(self.viewModel.shuffleModeAccessibilityLabel)
            .accessibilityHint("Cycle between shuffle off, shuffle, and radio")

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
                .buttonStyle(.plain)
                .disabled(!self.viewModel.canGoBack)
                .accessibilityLabel("Previous")
                .accessibilityHint("Play previous track")

                if self.viewModel.isLoading {
                    SpinnerView(lineWidth: 4)
                        .frame(width: 48, height: 48)
                        .accessibilityLabel("Loading")
                } else {
                    Button {
                        self.viewModel.togglePlayPause()
                    } label: {
                        Image(systemName: self.viewModel.playPauseIconName)
                            .font(.system(size: 56))
                            .foregroundColor(.white)
                            .frame(width: 48, height: 48)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(self.viewModel.isPlaying ? "Pause" : "Play")
                    .accessibilityHint(self.viewModel
                        .isPlaying ? "Pause playback" : "Resume playback")
                }

                Button {
                    self.viewModel.next()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                        .frame(width: 48, height: 48)
                }
                .buttonStyle(.plain)
                .disabled(!self.viewModel.canSkipForward)
                .accessibilityLabel("Next")
                .accessibilityHint("Play next track")
            }

            Spacer()

            Button {
                self.viewModel.cycleRepeatMode()
            } label: {
                Image(systemName: self.viewModel.repeatIconName)
                    .font(.system(size: 18))
                    .foregroundColor(self.viewModel.isRepeatActive ? Color
                        .purp : Color(.systemGray))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(self.viewModel.repeatMode == .one ? "Repeat One" : self.viewModel
                .repeatMode == .all ? "Repeat All" : "Repeat Off")
            .accessibilityHint("Cycle repeat mode")
        }
    }

    private var queueToggleButton: some View {
        HStack(alignment: .center) {
            Spacer()

            Button {
                self.viewModel.toggleQueue()
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 20))
                    .foregroundColor(self.viewModel.showQueue ? Color.purp : Color(.systemGray))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(self.viewModel.showQueue ? "Hide Queue" : "Show Queue")
            .accessibilityHint("Toggle the playback queue")
        }
    }

    @ViewBuilder
    private var shareButton: some View {
        if let iconSvg = self.viewModel.currentMediaSourceIconSvg,
           let shareURL = self.viewModel.shareURL
        {
            ShareLink(item: shareURL) {
                SVGImageView(svgString: iconSvg, size: 60)
                    .frame(width: 40, height: 40)
                    .shadow(color: .black.opacity(0.6), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Share")
            .accessibilityHint("Share a link to this track")
        }
    }
}

#Preview {
    NowPlayingView(viewModel: NowPlayingViewModel())
        .preferredColorScheme(.dark)
}
