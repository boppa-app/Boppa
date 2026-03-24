import SwiftData
import SwiftUI

// TODO: Swiping up in search view should refresh results

struct SearchView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = SearchViewModel()
    @FocusState private var isSearchFieldFocused: Bool

    private var showCategorySuggestions: Bool {
        self.isSearchFieldFocused && self.viewModel.isQueryActive
    }

    var body: some View {
        VStack(spacing: 0) {
            SearchToolbarView(viewModel: self.viewModel, isSearchFieldFocused: self.$isSearchFieldFocused)
            if self.showCategorySuggestions {
                self.categorySuggestions
            } else {
                self.contentArea
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            self.isSearchFieldFocused = false
        }
        .onAppear {
            self.viewModel.loadSources(modelContext: self.modelContext)
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
    }

    private var categorySuggestions: some View {
        List {
            ForEach(self.viewModel.availableCategories, id: \.self) { category in
                Button {
                    self.viewModel.selectCategory(category)
                    self.viewModel.search()
                    self.isSearchFieldFocused = false
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: category.icon)
                            .font(.system(size: 16))
                            .foregroundColor(.purp)
                            .frame(width: 24)
                        Text("Search \(category.rawValue)")
                            .font(.body)
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12))
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(Color(.systemGray5))
        }
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
    }

    private var resultsList: some View {
        ScrollFadeView {
            List {
                switch self.viewModel.results {
                case let .songs(songs):
                    ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                        Button {
                            self.playSong(song, from: songs)
                        } label: {
                            SongRow(
                                song: song,
                                isSelected: PlaybackService.shared.currentTrack?.url == song.url && song.url != nil,
                                isLoading: PlaybackService.shared.isLoading,
                                isPlaying: PlaybackService.shared.isPlaying
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.black)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowSeparatorTint(index == songs.count - 1 ? .clear : Color(.systemGray5))
                    }
                case let .albums(albums):
                    ForEach(Array(albums.enumerated()), id: \.element.id) { index, album in
                        AlbumRow(album: album)
                            .listRowBackground(Color.black)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .listRowSeparatorTint(index == albums.count - 1 ? .clear : Color(.systemGray5))
                    }
                case let .artists(artists):
                    ForEach(Array(artists.enumerated()), id: \.element.id) { index, artist in
                        ArtistRow(artist: artist)
                            .listRowBackground(Color.black)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .listRowSeparatorTint(index == artists.count - 1 ? .clear : Color(.systemGray5))
                    }
                case let .playlists(playlists):
                    ForEach(Array(playlists.enumerated()), id: \.element.id) { index, playlist in
                        PlaylistRow(playlist: playlist)
                            .listRowBackground(Color.black)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .listRowSeparatorTint(index == playlists.count - 1 ? .clear : Color(.systemGray5))
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
        }
    }

    private func playSong(_ song: Song, from songs: [Song]) {
        guard let source = self.viewModel.selectedSource else { return }
        PlaybackService.shared.playTrack(song, queue: songs, mediaSource: source)
    }
}

#Preview {
    SearchView()
        .modelContainer(for: MediaSource.self, inMemory: true)
        .preferredColorScheme(.dark)
}
