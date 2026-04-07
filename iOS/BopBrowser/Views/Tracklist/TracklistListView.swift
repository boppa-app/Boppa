import SwiftUI

struct TracklistListView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = TracklistListViewModel()

    let artist: Artist
    let artistDetail: ArtistDetail
    let source: MediaSource
    let title: String
    let preloadedAlbums: [Album]?
    var fallbackAlbums: [Album] = []

    init(artist: Artist, artistDetail: ArtistDetail, source: MediaSource, title: String, preloadedAlbums: [Album]? = nil, fallbackAlbums: [Album] = []) {
        self.artist = artist
        self.artistDetail = artistDetail
        self.source = source
        self.title = title
        self.preloadedAlbums = preloadedAlbums
        self.fallbackAlbums = fallbackAlbums
    }

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
        .onAppear {
            self.viewModel.fallbackAlbums = self.fallbackAlbums
            self.viewModel.load(
                artist: self.artist,
                artistDetail: self.artistDetail,
                source: self.source,
                preloadedAlbums: self.preloadedAlbums
            )
        }
    }

    private var content: some View {
        Group {
            if let errorMessage = self.viewModel.errorMessage {
                self.errorView(message: errorMessage)
            } else if self.viewModel.albums.isEmpty && self.viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if self.viewModel.albums.isEmpty {
                self.emptyState
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

    private var emptyState: some View {
        VStack(spacing: 12) {
            if #available(iOS 26.0, *) {
                Image(systemName: "music.note.square.stack")
                    .font(.system(size: 40))
                    .foregroundColor(Color(.systemGray5))
            } else {
                Image(systemName: "square.stack")
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
