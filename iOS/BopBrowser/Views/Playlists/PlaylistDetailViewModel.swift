import Foundation
import os
import SwiftData

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "BopBrowser",
    category: "PlaylistDetailViewModel"
)

@MainActor
@Observable
class PlaylistDetailViewModel {
    var songs: [Song] = []
    var isLoading = false
    var isRefreshing = false
    var errorMessage: String?
    var sortMode: PlaylistSortMode = .defaultOrder

    private var fetchTask: Task<Void, Never>?
    private var unsortedSongs: [Song] = []

    var displaySongs: [Song] {
        self.applySorting(self.songs)
    }

    func loadFromCache(playlist: StoredPlaylist, modelContext: ModelContext) {
        let sortedSongs = playlist.songs.sorted { $0.sortOrder < $1.sortOrder }
        self.unsortedSongs = sortedSongs.map { $0.toSong() }
        self.songs = self.unsortedSongs
        self.sortMode = playlist.sortMode
    }

    func fetchIfEmpty(
        playlist: StoredPlaylist,
        config: MediaSourceConfig,
        mediaSourceName: String,
        modelContext: ModelContext
    ) {
        self.loadFromCache(playlist: playlist, modelContext: modelContext)

        if self.songs.isEmpty {
            self.fetchAll(playlist: playlist, config: config, mediaSourceName: mediaSourceName, modelContext: modelContext)
        }
    }

    func refresh(
        playlist: StoredPlaylist,
        config: MediaSourceConfig,
        mediaSourceName: String,
        modelContext: ModelContext
    ) {
        self.isRefreshing = true
        self.fetchAll(playlist: playlist, config: config, mediaSourceName: mediaSourceName, modelContext: modelContext)
    }

    func setSortMode(_ mode: PlaylistSortMode, playlist: StoredPlaylist, modelContext: ModelContext) {
        if self.sortMode == mode {
            self.sortMode = .defaultOrder
        } else {
            self.sortMode = mode
        }
        playlist.sortMode = self.sortMode
        try? modelContext.save()
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
        playlist: StoredPlaylist,
        config: MediaSourceConfig,
        mediaSourceName: String,
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

                if playlist.isLikes {
                    try await PlaylistService.shared.fetchLikes(
                        config: config,
                        mediaSourceName: mediaSourceName,
                        playlist: playlist,
                        modelContext: modelContext,
                        contextService: MediaSourceContextProvider.shared,
                        onPageFetched: onPageFetched
                    )
                } else {
                    // TODO: Add user playlist retrieval functionality (listPlaylists)
                    return
                }

                guard !Task.isCancelled else { return }

                self.isLoading = false
                self.isRefreshing = false

                logger.info("Loaded \(self.songs.count) song(s) for '\(playlist.name)'")
            } catch {
                guard !Task.isCancelled else { return }

                self.isLoading = false
                self.isRefreshing = false
                self.errorMessage = error.localizedDescription
                logger.error("Fetch failed for '\(playlist.name)': \(error.localizedDescription)")
            }
        }
    }
}
