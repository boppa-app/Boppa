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
    var tracks: [Track] = []
    var isLoading = false
    var isRefreshing = false
    var errorMessage: String?
    var sortMode: TracklistSortMode = .defaultOrder

    private var fetchTask: Task<Void, Never>?
    private var unsortedTracks: [Track] = []

    var displayTracks: [Track] {
        self.applySorting(self.tracks)
    }

    func load(
        tracklist: Tracklist,
        config: MediaSourceConfig,
        modelContext: ModelContext
    ) {
        if let stored = tracklist.storedTracklist {
            self.loadFromCache(storedTracklist: stored, modelContext: modelContext)
        }

        if self.tracks.isEmpty {
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
        let sortedTracks = storedTracklist.tracks.sorted { $0.sortOrder < $1.sortOrder }
        self.unsortedTracks = sortedTracks.map { $0.toTrack() }
        self.tracks = self.unsortedTracks
        self.sortMode = storedTracklist.sortMode
    }

    private func applySorting(_ tracks: [Track]) -> [Track] {
        switch self.sortMode {
        case .defaultOrder:
            return tracks
        case .reversed:
            return tracks.reversed()
        case .authorAZ:
            return tracks.sorted { ($0.subtitle ?? "").localizedCaseInsensitiveCompare($1.subtitle ?? "") == .orderedAscending }
        case .authorZA:
            return tracks.sorted { ($0.subtitle ?? "").localizedCaseInsensitiveCompare($1.subtitle ?? "") == .orderedDescending }
        case .nameAZ:
            return tracks.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .nameZA:
            return tracks.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedDescending }
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
                let onPageFetched: ([Track]) -> Void = { [weak self] allTracksSoFar in
                    guard let self else { return }
                    self.unsortedTracks = allTracksSoFar
                    self.tracks = allTracksSoFar
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
                    let tracks = try await TracklistService.shared.fetchAlbum(
                        album: album,
                        config: config,
                        mediaSourceName: tracklist.mediaSourceName,
                        onPageFetched: onPageFetched
                    )
                    guard !Task.isCancelled else { return }
                    self.unsortedTracks = tracks
                    self.tracks = tracks
                case .playlist:
                    // TODO: Add user playlist retrieval functionality (listPlaylists)
                    return
                }

                guard !Task.isCancelled else { return }

                self.isLoading = false
                self.isRefreshing = false

                logger.info("Loaded \(self.tracks.count) track(s) for '\(tracklist.name)'")
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
