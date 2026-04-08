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
    var hasMorePages = false

    private var fetchTask: Task<Void, Never>?
    private var unsortedTracks: [Track] = []
    private var paginationContext: [String: Any]?
    private var currentTracklist: Tracklist?
    private var currentSource: MediaSource?

    var displayTracks: [Track] {
        self.applySorting(self.tracks)
    }

    func load(
        tracklist: Tracklist,
        source: MediaSource,
        modelContext: ModelContext
    ) {
        self.currentTracklist = tracklist
        self.currentSource = source

        if let stored = tracklist.storedTracklist {
            self.loadFromCache(storedTracklist: stored, modelContext: modelContext)
        }

        if self.tracks.isEmpty {
            self.fetchAll(tracklist: tracklist, source: source, modelContext: modelContext)
        }
    }

    func refresh(
        tracklist: Tracklist,
        source: MediaSource,
        modelContext: ModelContext
    ) {
        guard tracklist.isPersisted else { return }
        self.isRefreshing = true
        self.fetchAll(tracklist: tracklist, source: source, modelContext: modelContext)
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
        source: MediaSource,
        modelContext: ModelContext
    ) {
        self.fetchTask?.cancel()
        self.isLoading = true
        self.errorMessage = nil

        self.fetchTask = Task {
            do {
                switch tracklist.tracklistType {
                case .likes:
                    let onPageFetched: ([Track]) -> Void = { [weak self] allTracksSoFar in
                        guard let self else { return }
                        self.unsortedTracks = allTracksSoFar
                        self.tracks = allTracksSoFar
                    }
                    guard let stored = tracklist.storedTracklist else { return }
                    try await TracklistService.shared.fetchLikes(
                        mediaSource: source,
                        tracklist: stored,
                        modelContext: modelContext,
                        onPageFetched: onPageFetched
                    )
                case .album, .playlist, .artistSongs, .artistVideos:
                    let response = try await TracklistService.shared.fetchTracklist(
                        tracklist: tracklist,
                        mediaSource: source,
                        previousResult: nil
                    )
                    guard !Task.isCancelled else { return }
                    self.unsortedTracks = response.tracks
                    self.tracks = response.tracks
                    self.paginationContext = response.tracks.isEmpty ? nil : response.paginationContext
                    self.hasMorePages = !response.tracks.isEmpty && response.paginationContext != nil
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

    func loadNextPage() {
        guard let tracklist = self.currentTracklist,
              let source = self.currentSource,
              let paginationContext = self.paginationContext,
              !self.isLoading
        else {
            return
        }

        self.isLoading = true

        Task {
            do {
                let response = try await TracklistService.shared.fetchTracklist(
                    tracklist: tracklist,
                    mediaSource: source,
                    previousResult: paginationContext
                )

                guard !Task.isCancelled else { return }

                self.unsortedTracks.append(contentsOf: response.tracks)
                self.tracks = self.unsortedTracks
                self.paginationContext = response.paginationContext
                self.hasMorePages = response.paginationContext != nil
                self.isLoading = false

                logger.info("Loaded next page: \(response.tracks.count) track(s), total: \(self.tracks.count)")
            } catch {
                guard !Task.isCancelled else { return }

                self.isLoading = false
                self.errorMessage = error.localizedDescription
                logger.error("Failed to load next page: \(error.localizedDescription)")
            }
        }
    }
}
