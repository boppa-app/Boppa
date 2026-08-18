import SwiftUI

struct TrackActionsSheet: View {
    let track: Track
    let mediaSource: StoredMediaSource
    var isMediaSourceEnabled: Bool = true
    var onArtistSelected: ((Artist) -> Void)?
    var onAlbumSelected: ((Tracklist) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var isShowingAddToPlaylist = false
    @State private var selectedDetent: PresentationDetent = .medium
    @State private var allowsMediumDetent = true

    private var albumIcon: String {
        if #available(iOS 26.0, *) {
            return "music.note.square.stack.fill"
        } else {
            return "square.stack.fill"
        }
    }

    var body: some View {
        Group {
            if self.isShowingAddToPlaylist {
                AddToPlaylistSheet(
                    track: self.track,
                    onBack: { self.showActions() }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                self.actionsContent
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .presentationDetents(
            self.allowsMediumDetent ? [.medium, .large] : [.large],
            selection: self.$selectedDetent
        )
        .presentationDragIndicator(.visible)
        .presentationBackground(Color(.systemGray6))
    }

    private let transitionDuration: TimeInterval = 0.1

    private func showAddToPlaylist() {
        withAnimation(.easeInOut(duration: self.transitionDuration)) {
            self.isShowingAddToPlaylist = true
            self.selectedDetent = .large
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + self.transitionDuration) {
            self.allowsMediumDetent = false
        }
    }

    private func showActions() {
        self.allowsMediumDetent = true
        withAnimation(.easeInOut(duration: self.transitionDuration)) {
            self.isShowingAddToPlaylist = false
            self.selectedDetent = .medium
        }
    }

    private var actionsContent: some View {
        VStack(spacing: 0) {
            self.header
                .padding(.top, 20)
                .padding(.bottom, 12)

            List {
                if self.isMediaSourceEnabled {
                    if self.mediaSource.config.data.list?.trackRadio != nil {
                        Button {
                            PlaybackService.shared.startRadio(from: self.track)
                            self.dismiss()
                        } label: {
                            self.actionRowLabel(
                                name: "Start Radio",
                                icon: "dot.radiowaves.left.and.right"
                            )
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color(.systemGray6))
                        .listRowInsets(EdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20))
                        .listRowSeparator(.hidden)
                        .accessibilityLabel("Start Radio")
                        .accessibilityHint("Play a radio queue starting from \(self.track.title)")
                    }

                    Button {
                        TrackQueueManager.shared.playNext(self.track)
                        self.dismiss()
                    } label: {
                        self.actionRowLabel(
                            name: "Play Next",
                            icon: "text.line.first.and.arrowtriangle.forward"
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color(.systemGray6))
                    .listRowInsets(EdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20))
                    .listRowSeparator(.hidden)
                    .accessibilityLabel("Play Next")
                    .accessibilityHint("Play \(self.track.title) after the current track")

                    Button {
                        TrackQueueManager.shared.addToQueue(self.track)
                        self.dismiss()
                    } label: {
                        self.actionRowLabel(
                            name: "Add to Queue",
                            icon: "text.line.last.and.arrowtriangle.forward"
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color(.systemGray6))
                    .listRowInsets(EdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20))
                    .listRowSeparator(.hidden)
                    .accessibilityLabel("Add to Queue")
                    .accessibilityHint("Add \(self.track.title) to the end of the queue")
                }

                if self.isMediaSourceEnabled {
                    ForEach(self.track.artists) { artist in
                        if self.mediaSource.config.data.get?.artist != nil {
                            Button {
                                self.dismiss()
                                self.onArtistSelected?(artist)
                            } label: {
                                self.navigationRowLabel(
                                    name: artist.name,
                                    icon: "person.fill"
                                )
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color(.systemGray6))
                            .listRowInsets(EdgeInsets(
                                top: 14,
                                leading: 20,
                                bottom: 14,
                                trailing: 20
                            ))
                            .listRowSeparator(.hidden)
                            .accessibilityLabel("Go to \(artist.name)")
                            .accessibilityHint("View artist page for \(artist.name)")
                        }
                    }

                    ForEach(self.track.albums) { album in
                        if self.mediaSource.config.data.list?.album != nil {
                            Button {
                                self.dismiss()
                                self.onAlbumSelected?(album)
                            } label: {
                                self.navigationRowLabel(
                                    name: album.title,
                                    icon: self.albumIcon
                                )
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color(.systemGray6))
                            .listRowInsets(EdgeInsets(
                                top: 14,
                                leading: 20,
                                bottom: 14,
                                trailing: 20
                            ))
                            .listRowSeparator(.hidden)
                            .accessibilityLabel("Go to \(album.title)")
                            .accessibilityHint("View album page for \(album.title)")
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .background(Color(.systemGray6))
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                ArtworkView(
                    lowResUrl: self.track.resolvedLowResArtworkUrl,
                    highResUrl: self.track.resolvedHighResArtworkUrl,
                    size: 56,
                    placeholderBackground: .purp
                )
                VStack(alignment: .leading, spacing: 4) {
                    MarqueeText(
                        self.track.title,
                        font: .title3,
                        fontWeight: .semibold,
                        uniqueId: self.track.id.uuidString
                    )
                    if let subtitle = self.track.subtitle {
                        MarqueeText(
                            subtitle,
                            font: .subheadline,
                            foregroundColor: Color(.systemGray),
                            uniqueId: self.track.id.uuidString
                        )
                    }
                }
                Spacer()
                Button {
                    self.showAddToPlaylist()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 22))
                        .foregroundColor(.purp)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add to Playlist")
                .accessibilityHint("Add this track to a playlist")

                Button {
                    PlaylistManager.shared.togglePlaylist(self.track, playlistId: "likes")
                } label: {
                    Image(systemName: PlaylistManager.shared.isInPlaylist(
                        self.track,
                        playlistId: "likes"
                    ) ? "heart.fill" : "heart")
                        .font(.system(size: 22))
                        .foregroundColor(PlaylistManager.shared.isInPlaylist(
                            self.track,
                            playlistId: "likes"
                        ) ? .purp : Color(.systemGray))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(PlaylistManager.shared.isInPlaylist(
                    self.track,
                    playlistId: "likes"
                ) ? "Unlike" : "Like")
                .accessibilityHint(PlaylistManager.shared.isInPlaylist(
                    self.track,
                    playlistId: "likes"
                ) ? "Remove from Likes" : "Add to Likes")
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 28)

            Rectangle()
                .fill(Color(.systemGray5))
                .frame(height: 2)
                .padding(.horizontal, 16)
        }
    }

    private func actionRowLabel(name: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.purp)
                .frame(width: 24)
            Text(name)
                .bold()
                .foregroundColor(.white)
                .font(.body)
                .lineLimit(1)
            Spacer()
        }
        .contentShape(Rectangle())
    }

    private func navigationRowLabel(name: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.purp)
                .frame(width: 24)
            (
                Text("Go to ")
                    .italic()
                    .foregroundColor(.white)
                    + Text(name)
                    .bold()
                    .foregroundColor(.purp)
            )
            .font(.body)
            .lineLimit(1)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.purp)
        }
        .contentShape(Rectangle())
    }
}
