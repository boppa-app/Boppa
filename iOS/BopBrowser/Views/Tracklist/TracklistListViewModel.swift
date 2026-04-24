import Foundation
import os
import SwiftData

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "BopBrowser",
    category: "TracklistListViewModel"
)

enum TracklistListType {
    case albums
    case playlists
}

@MainActor
@Observable
class TracklistListViewModel {
    var tracklists: [Tracklist] = []
    var isLoading = false
    var errorMessage: String?
    var sortMode: SortMode = .defaultOrder

    let searchHandler = FuzzySearchHandler<Tracklist>()

    private var fetchTask: Task<Void, Never>?
    private var didLoad = false

    var displayTracklists: [Tracklist] {
        let items = self.searchHandler.displayItems(from: self.tracklists)
        if self.searchHandler.filteredItems != nil {
            return items
        }
        return self.applySorting(items)
    }

    func updateSearch(_ text: String) {
        self.searchHandler.updateSearch(text, items: self.tracklists)
    }

    func setSortMode(_ mode: SortMode) {
        if self.sortMode == mode {
            self.sortMode = .defaultOrder
        } else {
            self.sortMode = mode
        }
    }

    private func applySorting(_ tracklists: [Tracklist]) -> [Tracklist] {
        switch self.sortMode {
        case .defaultOrder:
            return tracklists
        case .reversed:
            return tracklists.reversed()
        case .nameAZ:
            return tracklists.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .nameZA:
            return tracklists.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedDescending }
        case .authorAZ:
            return tracklists.sorted { ($0.subtitle ?? "").localizedCaseInsensitiveCompare($1.subtitle ?? "") == .orderedAscending }
        case .authorZA:
            return tracklists.sorted { ($0.subtitle ?? "").localizedCaseInsensitiveCompare($1.subtitle ?? "") == .orderedDescending }
        }
    }

    func loadFromArtist(
        type: TracklistListType,
        artist: Artist,
        artistDetail: ArtistDetail,
        mediaSource: MediaSource
    ) {
        switch type {
        case .albums:
            self.fetchAlbums(artist: artist, artistDetail: artistDetail, mediaSource: mediaSource)
        case .playlists:
            self.fetchPlaylists(artist: artist, artistDetail: artistDetail, mediaSource: mediaSource)
        }
    }

    func loadFromLibrary(type: TracklistListType, visibleMediaSourceIds: Set<String>, modelContext: ModelContext) {
        let typeString: String
        switch type {
        case .albums:
            typeString = "album"
        case .playlists:
            typeString = "playlist"
        }

        let descriptor = FetchDescriptor<StoredTracklist>(
            predicate: #Predicate { $0.tracklistType == typeString }
        )

        let storedTracklists = (try? modelContext.fetch(descriptor)) ?? []
        self.tracklists = storedTracklists
            .filter { visibleMediaSourceIds.contains($0.mediaSourceId) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .map { Tracklist(storedTracklist: $0) }

        logger.info("Loaded \(self.tracklists.count) \(typeString)(s) from library")
    }

    private func fetchAlbums(
        artist: Artist,
        artistDetail: ArtistDetail,
        mediaSource: MediaSource
    ) {
        self.fetchTask?.cancel()
        self.isLoading = true
        self.errorMessage = nil

        self.fetchTask = Task {
            do {
                let result = try await TracklistService.shared.fetchAlbumsForArtist(
                    artist: artist,
                    artistDetail: artistDetail,
                    mediaSource: mediaSource
                )

                guard !Task.isCancelled else { return }

                self.tracklists = result
                self.isLoading = false

                logger.info("Loaded \(self.tracklists.count) album(s) for artist '\(artist.name)'")
            } catch {
                guard !Task.isCancelled else { return }

                self.isLoading = false
                self.errorMessage = error.localizedDescription
                logger.error("Fetch albums failed for artist '\(artist.name)': \(error.localizedDescription)")
            }
        }
    }

    private func fetchPlaylists(
        artist: Artist,
        artistDetail: ArtistDetail,
        mediaSource: MediaSource
    ) {
        self.fetchTask?.cancel()
        self.isLoading = true
        self.errorMessage = nil

        self.fetchTask = Task {
            do {
                let result = try await TracklistService.shared.fetchPlaylistsForArtist(
                    artist: artist,
                    artistDetail: artistDetail,
                    mediaSource: mediaSource
                )

                guard !Task.isCancelled else { return }

                self.tracklists = result
                self.isLoading = false

                logger.info("Loaded \(self.tracklists.count) playlist(s) for artist '\(artist.name)'")
            } catch {
                guard !Task.isCancelled else { return }

                self.isLoading = false
                self.errorMessage = error.localizedDescription
                logger.error("Fetch playlists failed for artist '\(artist.name)': \(error.localizedDescription)")
            }
        }
    }
}
