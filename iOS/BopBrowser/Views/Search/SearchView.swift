import SwiftData
import SwiftUI

// TODO: Swiping up in search view should refresh results

struct SearchView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = SearchViewModel()
    @State private var cacheManager = SearchCacheManager()
    @State private var trackForActions: Track?
    @State private var pendingArtist: Artist?
    @State private var pendingAlbum: Album?
    @FocusState private var isSearchFieldFocused: Bool

    private var showCategorySuggestions: Bool {
        self.isSearchFieldFocused && self.viewModel.isQueryActive
    }

    private var showRecentSearches: Bool {
        self.isSearchFieldFocused && !self.viewModel.isQueryActive
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                SearchToolbarView(
                    viewModel: self.viewModel,
                    isSearchFieldFocused: self.$isSearchFieldFocused,
                    onSearch: {
                        self.cacheManager.saveQuery(
                            self.viewModel.searchQuery,
                            category: self.viewModel.selectedCategory,
                            modelContext: self.modelContext
                        )
                    }
                )
                if self.showCategorySuggestions {
                    self.categorySuggestions
                } else if self.showRecentSearches {
                    self.recentSearchesView
                } else {
                    self.contentArea
                }
            }
            .onAppear {
                self.viewModel.loadSources(modelContext: self.modelContext)
                self.cacheManager.load(modelContext: self.modelContext)
            }
            .onReceive(NotificationCenter.default.publisher(for: .mediaSourceAdded)) { _ in
                self.viewModel.loadSources(modelContext: self.modelContext)
            }
            .onReceive(NotificationCenter.default.publisher(for: .mediaSourceRemoved)) { notification in
                let removedNames = notification.userInfo?["names"] as? [String] ?? []
                if let selected = self.viewModel.selectedSource, removedNames.contains(selected.name) {
                    self.viewModel.clearSearch()
                }
                self.viewModel.loadSources(modelContext: self.modelContext)
            }
            .onReceive(NotificationCenter.default.publisher(for: .mediaSourceUpdated)) { _ in
                self.viewModel.loadSources(modelContext: self.modelContext)
            }
        }
    }

    private var categorySuggestions: some View {
        List {
            ForEach(self.viewModel.availableCategories, id: \.self) { category in
                Button {
                    self.viewModel.selectCategory(category)
                    self.viewModel.search()
                    self.cacheManager.saveQuery(
                        self.viewModel.searchQuery,
                        category: category,
                        modelContext: self.modelContext
                    )
                    self.isSearchFieldFocused = false
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: category.icon)
                            .font(.system(size: 16))
                            .foregroundColor(.purp)
                            .frame(width: 24)
                        Text("Search \(category.rawValue)")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16))
                            .foregroundColor(Color(.systemGray3))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.black)
                .listRowInsets(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
                .listRowSeparatorTint(category == self.viewModel.availableCategories.last ? .clear : Color(.systemGray5))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.immediately)
        .contentShape(Rectangle())
        .onTapGesture {
            self.isSearchFieldFocused = false
        }
    }

    private var contentArea: some View {
        Group {
            if let errorMessage = self.viewModel.errorMessage {
                self.errorView(message: errorMessage)
            } else if self.viewModel.results.isEmpty, !self.viewModel.isSearching {
                self.emptyStateView
            } else {
                self.resultsList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var recentSearchesView: some View {
        VStack(spacing: 0) {
            SearchCacheView(
                cachedQueries: self.cacheManager.cachedQueries,
                onSelect: { cached in
                    if let category = cached.category {
                        self.viewModel.searchQuery = cached.query
                        self.viewModel.selectCategory(category)
                        self.viewModel.search()
                        self.isSearchFieldFocused = false
                        self.cacheManager.saveQuery(
                            cached.query,
                            category: category,
                            modelContext: self.modelContext
                        )
                    }
                },
                onRemove: { cached in
                    self.cacheManager.removeQuery(cached, modelContext: self.modelContext)
                },
                onClearAll: {
                    self.cacheManager.clearAll(modelContext: self.modelContext)
                }
            )
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            self.isSearchFieldFocused = false
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(Color(.systemGray5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            self.isSearchFieldFocused = false
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(self.viewModel.mediaSources.count == 0 ? Color(.systemGray) : .red)
            Text(message)
                .font(.callout)
                .foregroundColor(Color(.systemGray))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            self.isSearchFieldFocused = false
        }
    }

    private var resultsList: some View {
        ScrollFadeView {
            List {
                switch self.viewModel.results {
                case let .songs(tracks), let .videos(tracks):
                    ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                        TrackRow(
                            track: track,
                            isSelected: PlaybackService.shared.currentTrack?.url == track.url && track.url != nil,
                            isLoading: PlaybackService.shared.isLoading,
                            isPlaying: PlaybackService.shared.isPlaying,
                            onTap: { self.playTrack(track, from: tracks) },
                            onEllipsisTap: { self.trackForActions = track }
                        )
                        .alignmentGuide(.listRowSeparatorTrailing) { $0[.trailing] - 16 }
                        .listRowBackground(Color.black)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowSeparatorTint(index == tracks.count - 1 ? .clear : Color(.systemGray5))
                    }
                case let .albums(albums):
                    ForEach(Array(albums.enumerated()), id: \.element.id) { index, album in
                        if let source = self.viewModel.selectedSource,
                           source.config.data?.getAlbum != nil
                        {
                            NavigationLink {
                                TracklistView(
                                    tracklist: Tracklist(album: album, mediaSourceName: source.name, storedTracklist: TracklistService.shared.findStoredTracklist(id: album.id, modelContext: self.modelContext))
                                )
                            } label: {
                                AlbumRow(album: album)
                                    .alignmentGuide(.listRowSeparatorTrailing) { $0[.trailing] }
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.black)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .listRowSeparatorTint(index == albums.count - 1 ? .clear : Color(.systemGray5))
                            .padding(.trailing, 16)
                        } else {
                            AlbumRow(album: album)
                                .alignmentGuide(.listRowSeparatorTrailing) { $0[.trailing] - 16 }
                                .listRowBackground(Color.black)
                                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                                .listRowSeparatorTint(index == albums.count - 1 ? .clear : Color(.systemGray5))
                        }
                    }
                case let .artists(artists):
                    ForEach(Array(artists.enumerated()), id: \.element.id) { index, artist in
                        if let source = self.viewModel.selectedSource,
                           source.config.data?.getArtist != nil
                        {
                            NavigationLink {
                                ArtistDetailView(
                                    artist: artist,
                                    source: source
                                )
                            } label: {
                                ArtistRow(artist: artist)
                                    .alignmentGuide(.listRowSeparatorTrailing) { $0[.trailing] }
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.black)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .listRowSeparatorTint(index == artists.count - 1 ? .clear : Color(.systemGray5))
                            .padding(.trailing, 16)
                        } else {
                            ArtistRow(artist: artist)
                                .alignmentGuide(.listRowSeparatorTrailing) { $0[.trailing] - 16 }
                                .listRowBackground(Color.black)
                                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                                .listRowSeparatorTint(index == artists.count - 1 ? .clear : Color(.systemGray5))
                        }
                    }
                case let .playlists(playlists):
                    ForEach(Array(playlists.enumerated()), id: \.element.id) { index, playlist in
                        if let source = self.viewModel.selectedSource,
                           source.config.data?.getPlaylist != nil
                        {
                            NavigationLink {
                                TracklistView(
                                    tracklist: Tracklist(playlist: playlist, mediaSourceName: source.name, storedTracklist: TracklistService.shared.findStoredTracklist(id: playlist.id, modelContext: self.modelContext))
                                )
                            } label: {
                                PlaylistRow(playlist: playlist)
                                    .alignmentGuide(.listRowSeparatorTrailing) { $0[.trailing] }
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.black)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .listRowSeparatorTint(index == playlists.count - 1 ? .clear : Color(.systemGray5))
                            .padding(.trailing, 16)
                        } else {
                            PlaylistRow(playlist: playlist)
                                .alignmentGuide(.listRowSeparatorTrailing) { $0[.trailing] - 16 }
                                .listRowBackground(Color.black)
                                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                                .listRowSeparatorTint(index == playlists.count - 1 ? .clear : Color(.systemGray5))
                        }
                    }
                }

                if self.viewModel.hasMorePages {
                    ProgressView()
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.black)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowSeparator(.hidden)
                        .onAppear {
                            self.viewModel.loadNextPage()
                        }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.immediately)
        }
        .sheet(item: self.$trackForActions) { track in
            if let source = self.viewModel.selectedSource {
                TrackActionsSheet(
                    track: track,
                    source: source,
                    onArtistSelected: { artist in self.pendingArtist = artist },
                    onAlbumSelected: { album in self.pendingAlbum = album }
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color(.systemGray6))
            }
        }
        .navigationDestination(item: self.$pendingArtist) { artist in
            if let source = self.viewModel.selectedSource {
                ArtistDetailView(artist: artist, source: source)
            }
        }
        .navigationDestination(item: self.$pendingAlbum) { album in
            if let source = self.viewModel.selectedSource {
                TracklistView(
                    tracklist: Tracklist(album: album, mediaSourceName: source.name, storedTracklist: TracklistService.shared.findStoredTracklist(id: album.id, modelContext: self.modelContext))
                )
            }
        }
    }

    private func playTrack(_ track: Track, from tracks: [Track]) {
        guard let source = self.viewModel.selectedSource else { return }
        PlaybackService.shared.playTrack(track, queue: tracks, mediaSource: source)
    }
}

#Preview {
    SearchView()
        .modelContainer(for: MediaSource.self, inMemory: true)
        .preferredColorScheme(.dark)
}
