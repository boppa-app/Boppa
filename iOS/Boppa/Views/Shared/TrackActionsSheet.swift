import SwiftUI

struct TrackActionsSheet: View {
    let track: Track
    let mediaSource: MediaSource
    var onArtistSelected: ((Artist) -> Void)?
    var onAlbumSelected: ((Tracklist) -> Void)?

    @Environment(\.dismiss) private var dismiss

    private var albumIcon: String {
        if #available(iOS 26.0, *) {
            return "music.note.square.stack.fill"
        } else {
            return "square.stack.fill"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            self.header
                .padding(.top, 20)
                .padding(.bottom, 12)

            List {
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
                        .listRowInsets(EdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20))
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
                        .listRowInsets(EdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20))
                        .listRowSeparator(.hidden)
                        .accessibilityLabel("Go to \(album.title)")
                        .accessibilityHint("View album page for \(album.title)")
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
                    url: self.track.artworkUrl,
                    size: 56,
                    placeholderBackground: .purp
                )
                VStack(alignment: .leading, spacing: 4) {
                    MarqueeText(
                        self.track.title,
                        font: .title3,
                        fontWeight: .semibold
                    )
                    if let subtitle = self.track.subtitle {
                        MarqueeText(
                            subtitle,
                            font: .subheadline,
                            foregroundColor: Color(.systemGray)
                        )
                    }
                }
                Spacer()
                Button {
                    PlaylistManager.shared.togglePlaylist(self.track, playlistId: "likes")
                } label: {
                    Image(systemName: PlaylistManager.shared.isInPlaylist(self.track, playlistId: "likes") ? "heart.fill" : "heart")
                        .font(.system(size: 22))
                        .foregroundColor(PlaylistManager.shared.isInPlaylist(self.track, playlistId: "likes") ? .purp : Color(.systemGray))
                        .frame(width: 36, height: 36)
                }
                .accessibilityLabel(PlaylistManager.shared.isInPlaylist(self.track, playlistId: "likes") ? "Unlike" : "Like")
                .accessibilityHint(PlaylistManager.shared.isInPlaylist(self.track, playlistId: "likes") ? "Remove from Likes" : "Add to Likes")
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
