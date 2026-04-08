import SwiftUI

struct TracklistListView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = TracklistListViewModel()

    let artist: Artist
    let artistDetail: ArtistDetail
    let source: MediaSource
    let title: String

    var body: some View {
        VStack(spacing: 0) {
            DetailHeaderView(
                title: self.title,
                highlightedTitle: self.artist.name,
                onBack: { self.dismiss() }
            )
            self.content
        }
        .navigationBarHidden(true)
        .enableSwipeBack()
        .onAppear {
            self.viewModel.load(
                artist: self.artist,
                artistDetail: self.artistDetail,
                source: self.source
            )
        }
    }

    private var content: some View {
        Group {
            if let errorMessage = self.viewModel.errorMessage {
                self.errorView(message: errorMessage)
            } else if self.viewModel.albums.isEmpty && self.viewModel.playlists.isEmpty && self.viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if self.viewModel.albums.isEmpty && self.viewModel.playlists.isEmpty {
                self.emptyState
            } else if !self.viewModel.playlists.isEmpty {
                self.playlistList
            } else {
                self.albumList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var albumList: some View {
        ScrollFadeView {
            List {
                ForEach(Array(self.viewModel.albums.enumerated()), id: \.element.id) { index, album in
                    if self.source.config.data?.getAlbum != nil {
                        NavigationLink {
                            TracklistView(
                                tracklist: Tracklist(album: album, mediaSourceName: self.source.name),
                                source: self.source
                            )
                        } label: {
                            AlbumRow(album: album)
                                .alignmentGuide(.listRowSeparatorTrailing) { $0[.trailing] }
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.black)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowSeparatorTint(index == self.viewModel.albums.count - 1 ? .clear : Color(.systemGray5))
                        .padding(.trailing, 16)
                    } else {
                        AlbumRow(album: album)
                            .alignmentGuide(.listRowSeparatorTrailing) { $0[.trailing] - 16 }
                            .listRowBackground(Color.black)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .listRowSeparatorTint(index == self.viewModel.albums.count - 1 ? .clear : Color(.systemGray5))
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    private var playlistList: some View {
        ScrollFadeView {
            List {
                ForEach(Array(self.viewModel.playlists.enumerated()), id: \.element.id) { index, playlist in
                    if self.source.config.data?.getPlaylist != nil {
                        NavigationLink {
                            TracklistView(
                                tracklist: Tracklist(playlist: playlist, mediaSourceName: self.source.name),
                                source: self.source
                            )
                        } label: {
                            PlaylistRow(playlist: playlist)
                                .alignmentGuide(.listRowSeparatorTrailing) { $0[.trailing] }
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.black)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowSeparatorTint(index == self.viewModel.playlists.count - 1 ? .clear : Color(.systemGray5))
                        .padding(.trailing, 16)
                    } else {
                        PlaylistRow(playlist: playlist)
                            .alignmentGuide(.listRowSeparatorTrailing) { $0[.trailing] - 16 }
                            .listRowBackground(Color.black)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .listRowSeparatorTint(index == self.viewModel.playlists.count - 1 ? .clear : Color(.systemGray5))
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            if #available(iOS 26.0, *) {
                Image(systemName: "music.note.square.stack.fill")
                    .font(.system(size: 40))
                    .foregroundColor(Color(.systemGray5))
            } else {
                Image(systemName: "square.stack.fill")
                    .font(.system(size: 40))
                    .foregroundColor(Color(.systemGray5))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.red)
            Text(message)
                .font(.callout)
                .foregroundColor(Color(.systemGray))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
