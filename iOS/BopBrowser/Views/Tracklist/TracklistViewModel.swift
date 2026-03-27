import Foundation
import os
import SwiftData

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "BopBrowser",
    category: "TracklistViewModel"
)

@MainActor
@Observable
class TracklistViewModel {
    var songs: [Song] = []
    var isLoading = false
    var isRefreshing = false
    var errorMessage: String?
    var sortMode: TracklistSortMode = .defaultOrder

    private var fetchTask: Task<Void, Never>?
    private var unsortedSongs: [Song] = []

    var displaySongs: [Song] {
        self.applySorting(self.songs)
    }

    func load(
        tracklist: Tracklist,
        config: MediaSourceConfig,
        modelContext: ModelContext
    ) {
        if let stored = tracklist.storedTracklist {
            self.loadFromCache(storedTracklist: stored, modelContext: modelContext)
        }

        if self.songs.isEmpty {
            self.fetchAll(tracklist: tracklist, config: config, modelContext: modelContext)
        }
    }

    func refresh(
        tracklist: Tracklist,
        config: MediaSourceConfig,
        modelContext: ModelContext
    ) {
        guard tracklist.isPersisted else { return }
        self.isRefreshing = true
        self.fetchAll(tracklist: tracklist, config: config, modelContext: modelContext)
    }

    func setSortMode(_ mode: TracklistSortMode, tracklist: Tracklist, modelContext: ModelContext) {
        if self.sortMode == mode {
            self.sortMode = .defaultOrder
        } else {
            self.sortMode = mode
        }
        if let stored = tracklist.storedTracklist {
            stored.sortMode = self.sortMode
            try? modelContext.save()
        }
    }

    private func loadFromCache(storedTracklist: StoredTracklist, modelContext: ModelContext) {
        let sortedSongs = storedTracklist.songs.sorted { $0.sortOrder < $1.sortOrder }
        self.unsortedSongs = sortedSongs.map { $0.toSong() }
        self.songs = self.unsortedSongs
        self.sortMode = storedTracklist.sortMode
    }

    private func applySorting(_ songs: [Song]) -> [Song] {
        switch self.sortMode {
        case .defaultOrder:
            return songs
        case .reversed:
            return songs.reversed()
        case .artistAZ:
            return songs.sorted { ($0.artist ?? "").localizedCaseInsensitiveCompare($1.artist ?? "") == .orderedAscending }
        case .artistZA:
            return songs.sorted { ($0.artist ?? "").localizedCaseInsensitiveCompare($1.artist ?? "") == .orderedDescending }
        case .songAZ:
            return songs.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .songZA:
            return songs.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedDescending }
        }
    }

    private func fetchAll(
        tracklist: Tracklist,
        config: MediaSourceConfig,
        modelContext: ModelContext
    ) {
        self.fetchTask?.cancel()
        self.isLoading = true
        self.errorMessage = nil

        self.fetchTask = Task {
            do {
                let onPageFetched: ([Song]) -> Void = { [weak self] allSongsSoFar in
                    guard let self else { return }
                    self.unsortedSongs = allSongsSoFar
                    self.songs = allSongsSoFar
                }

                switch tracklist.tracklistType {
                case .likes:
                    guard let stored = tracklist.storedTracklist else { return }
                    try await TracklistService.shared.fetchLikes(
                        config: config,
                        mediaSourceName: tracklist.mediaSourceName,
                        tracklist: stored,
                        modelContext: modelContext,
                        onPageFetched: onPageFetched
                    )
                case let .album(album):
                    let songs = try await TracklistService.shared.fetchAlbum(
                        album: album,
                        config: config,
                        mediaSourceName: tracklist.mediaSourceName,
                        onPageFetched: onPageFetched
                    )
                    guard !Task.isCancelled else { return }
                    self.unsortedSongs = songs
                    self.songs = songs
                case .playlist:
                    // TODO: Add user playlist retrieval functionality (listPlaylists)
                    return
                }

                guard !Task.isCancelled else { return }

                self.isLoading = false
                self.isRefreshing = false

                logger.info("Loaded \(self.songs.count) song(s) for '\(tracklist.name)'")
            } catch {
                guard !Task.isCancelled else { return }

                self.isLoading = false
                self.isRefreshing = false
                self.errorMessage = error.localizedDescription
                logger.error("Fetch failed for '\(tracklist.name)': \(error.localizedDescription)")
            }
        }
    }
}
