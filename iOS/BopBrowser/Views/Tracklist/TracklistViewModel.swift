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
    var tracklist: Tracklist
    var tracks: [Track] = []
    var isLoading = false
    var isRefreshing = false
    var isSaving = false
    var isPinned = false
    var errorMessage: String?
    var sortMode: TracklistSortMode = .defaultOrder
    var hasMorePages = false
    var pageLoadId = 0

    let searchHandler = FuzzySearchHandler<Track>()

    private var fetchTask: Task<Void, Never>?
    private var unsortedTracks: [Track] = []
    private var paginationContext: [String: Any]?

    init(tracklist: Tracklist) {
        self.tracklist = tracklist
    }

    var displayTracks: [Track] {
        self.applySorting(self.searchHandler.displayItems(from: self.tracks))
    }

    func updateSearch(_ text: String) {
        self.searchHandler.updateSearch(text, items: self.tracks)
    }

    var canRefresh: Bool {
        self.tracklist.isPersisted
    }

    func load(modelContext: ModelContext) {
        if let stored = self.tracklist.storedTracklist {
            self.loadFromCache(storedTracklist: stored, modelContext: modelContext)
        }

        if self.tracks.isEmpty {
            self.fetchFirstPage(modelContext: modelContext)
        }
    }

    func refresh(modelContext: ModelContext) {
        guard self.tracklist.isPersisted else { return }
        self.isRefreshing = true

        Task {
            do {
                _ = try await TracklistService.shared.saveTracklistToLibrary(
                    tracklist: self.tracklist,
                    modelContext: modelContext,
                    onPageFetched: { [weak self] allTracksSoFar in
                        guard let self else { return }
                        self.unsortedTracks = allTracksSoFar
                        self.tracks = allTracksSoFar
                        self.hasMorePages = false
                    }
                )

                self.isRefreshing = false

                logger.info("Refreshed tracklist '\(self.tracklist.title)' with \(self.tracks.count) track(s)")
            } catch {
                self.isRefreshing = false
                self.errorMessage = error.localizedDescription
                logger.error("Refresh failed for '\(self.tracklist.title)': \(error.localizedDescription)")
            }
        }
    }

    func setSortMode(_ mode: TracklistSortMode, modelContext: ModelContext) {
        if self.sortMode == mode {
            self.sortMode = .defaultOrder
        } else {
            self.sortMode = mode
        }
        if let stored = self.tracklist.storedTracklist {
            stored.sortMode = self.sortMode
            try? modelContext.save()
        }
    }

    private func loadFromCache(storedTracklist: StoredTracklist, modelContext: ModelContext) {
        let sortedTracks = storedTracklist.tracks.sorted { $0.sortOrder < $1.sortOrder }
        self.unsortedTracks = sortedTracks.map { $0.toTrack() }
        self.tracks = self.unsortedTracks
        self.sortMode = storedTracklist.sortMode
        self.isPinned = storedTracklist.isPinned
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

    private func fetchFirstPage(modelContext: ModelContext) {
        self.fetchTask?.cancel()
        self.isLoading = true
        self.errorMessage = nil

        self.fetchTask = Task {
            do {
                let response = try await TracklistService.shared.fetchTracklist(
                    tracklist: self.tracklist,
                    modelContext: modelContext,
                    previousResult: nil
                )
                guard !Task.isCancelled else { return }
                self.unsortedTracks = response.tracks
                self.tracks = response.tracks
                self.paginationContext = response.tracks.isEmpty ? nil : response.paginationContext
                self.hasMorePages = !response.tracks.isEmpty && response.paginationContext != nil

                guard !Task.isCancelled else { return }

                self.isLoading = false
                self.isRefreshing = false

                logger.info("Loaded \(self.tracks.count) track(s) for '\(self.tracklist.title)'")
            } catch {
                guard !Task.isCancelled else { return }

                self.isLoading = false
                self.isRefreshing = false
                self.errorMessage = error.localizedDescription
                logger.error("Fetch failed for '\(self.tracklist.title)': \(error.localizedDescription)")
            }
        }
    }

    func saveToLibrary(modelContext: ModelContext) {
        guard !self.isSaving else { return }
        self.isSaving = true

        Task {
            do {
                let stored = try await TracklistService.shared.saveTracklistToLibrary(
                    tracklist: self.tracklist,
                    modelContext: modelContext,
                    onPageFetched: { [weak self] allTracksSoFar in
                        guard let self else { return }
                        self.unsortedTracks = allTracksSoFar
                        self.tracks = allTracksSoFar
                        self.hasMorePages = false
                    }
                )

                self.tracklist = Tracklist(storedTracklist: stored)
                self.isSaving = false

                logger.info("Saved tracklist '\(self.tracklist.title)' to library")
            } catch {
                self.isSaving = false
                self.errorMessage = error.localizedDescription
                logger.error("Failed to save tracklist '\(self.tracklist.title)': \(error.localizedDescription)")
            }
        }
    }

    func deleteFromLibrary(modelContext: ModelContext) {
        guard let stored = self.tracklist.storedTracklist else { return }
        TracklistService.shared.deleteStoredTracklist(stored, modelContext: modelContext)
        logger.info("Deleted tracklist '\(self.tracklist.title)' from library")
    }

    func togglePin(modelContext: ModelContext) {
        guard let stored = self.tracklist.storedTracklist else { return }
        stored.isPinned = !self.isPinned
        try? modelContext.save()
        self.isPinned.toggle()
        logger.info("\(self.isPinned ? "Pinned" : "Unpinned") tracklist '\(self.tracklist.title)'")
    }

    func loadNextPage(modelContext: ModelContext) {
        guard let paginationContext = self.paginationContext,
              !self.isLoading
        else {
            return
        }

        self.isLoading = true

        Task {
            do {
                let response = try await TracklistService.shared.fetchTracklist(
                    tracklist: self.tracklist,
                    modelContext: modelContext,
                    previousResult: paginationContext
                )

                guard !Task.isCancelled else { return }

                self.unsortedTracks.append(contentsOf: response.tracks)
                self.tracks = self.unsortedTracks
                self.paginationContext = response.paginationContext
                self.hasMorePages = response.paginationContext != nil
                self.pageLoadId += 1
                self.isLoading = false

                logger.info("Loaded next page: \(response.tracks.count) track(s), total: \(self.tracks.count), hasMore: \(self.hasMorePages)")
            } catch {
                guard !Task.isCancelled else { return }

                self.isLoading = false
                self.errorMessage = error.localizedDescription
                logger.error("Failed to load next page: \(error.localizedDescription)")
            }
        }
    }
}
