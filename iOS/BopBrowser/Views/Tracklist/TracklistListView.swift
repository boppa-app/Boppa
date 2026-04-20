import SwiftUI

struct TracklistListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = TracklistListViewModel()

    let artist: Artist?
    let artistDetail: ArtistDetail?
    let mediaSource: MediaSource?
    let type: TracklistListType
    let title: String
    let isLibraryMode: Bool
    let visibleMediaSourceIds: Set<String>

    init(
        artist: Artist,
        artistDetail: ArtistDetail,
        mediaSource: MediaSource,
        type: TracklistListType,
        title: String
    ) {
        self.artist = artist
        self.artistDetail = artistDetail
        self.mediaSource = mediaSource
        self.type = type
        self.title = title
        self.isLibraryMode = false
        self.visibleMediaSourceIds = []
    }

    init(type: TracklistListType, title: String, visibleMediaSourceIds: Set<String>) {
        self.artist = nil
        self.artistDetail = nil
        self.mediaSource = nil
        self.type = type
        self.title = title
        self.isLibraryMode = true
        self.visibleMediaSourceIds = visibleMediaSourceIds
    }

    var body: some View {
        VStack(spacing: 0) {
            DetailHeaderView(
                title: self.title,
                highlightedTitle: self.artist?.name,
                onBack: { self.dismiss() }
            )
            self.content
        }
        .navigationBarHidden(true)
        .enableSwipeBack()
        .onAppear {
            if self.isLibraryMode {
                self.viewModel.loadFromLibrary(
                    type: self.type,
                    visibleMediaSourceIds: self.visibleMediaSourceIds,
                    modelContext: self.modelContext
                )
            } else if let artist = self.artist,
                      let artistDetail = self.artistDetail,
                      let mediaSource = self.mediaSource
            {
                self.viewModel.loadFromArtist(
                    type: self.type,
                    artist: artist,
                    artistDetail: artistDetail,
                    mediaSource: mediaSource
                )
            }
        }
    }

    private var content: some View {
        Group {
            if let errorMessage = self.viewModel.errorMessage {
                self.errorView(message: errorMessage)
            } else if self.viewModel.tracklists.isEmpty && self.viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if self.viewModel.tracklists.isEmpty {
                self.emptyState
            } else {
                self.tracklistList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var canNavigateToTracklist: Bool {
        if self.isLibraryMode { return true }
        guard let mediaSource = self.mediaSource else { return false }
        switch self.type {
        case .albums:
            return mediaSource.config.data?.getAlbum != nil
        case .playlists:
            return mediaSource.config.data?.getPlaylist != nil
        }
    }

    private var tracklistList: some View {
        ScrollFadeView {
            List {
                ForEach(Array(self.viewModel.tracklists.enumerated()), id: \.element.id) { index, tracklist in
                    if self.canNavigateToTracklist {
                        NavigationLink {
                            TracklistView(tracklist: tracklist)
                        } label: {
                            TracklistRow(tracklist: tracklist, showMediaSourceIcon: self.isLibraryMode)
                                .alignmentGuide(.listRowSeparatorTrailing) { $0[.trailing] }
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.black)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowSeparatorTint(index == self.viewModel.tracklists.count - 1 ? .clear : Color(.systemGray5))
                        .padding(.trailing, 16)
                    } else {
                        TracklistRow(tracklist: tracklist, showMediaSourceIcon: self.isLibraryMode)
                            .alignmentGuide(.listRowSeparatorTrailing) { $0[.trailing] - 16 }
                            .listRowBackground(Color.black)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .listRowSeparatorTint(index == self.viewModel.tracklists.count - 1 ? .clear : Color(.systemGray5))
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
