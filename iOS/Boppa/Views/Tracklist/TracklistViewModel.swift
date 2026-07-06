import Foundation
import os

extension Notification.Name {
    static let tracklistPinChanged = Notification.Name("tracklistPinChanged")
    static let tracklistLibraryChanged = Notification.Name("tracklistLibraryChanged")
}

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "Boppa",
    category: "TracklistViewModel"
)

@MainActor
@Observable
class TracklistViewModel {
    var tracklist: Tracklist
    var isPersisted: Bool
    var tracks: [Track] = []
    var isLoading = false
    var isRefreshing = false
    var isSaving = false
    var isPinned = false
    var errorMessage: String?
    var sortMode: SortMode = .defaultOrder
    var hasMorePages = false
    var pageLoadId = 0

    let searchHandler = FuzzySearchHandler<Track>()

    private var fetchTask: Task<Void, Never>?
    private var unsortedTracks: [Track] = []
    private var continuation: [String: Any]?

    @ObservationIgnored
    private var observers: [NSObjectProtocol] = []

    init(tracklist: Tracklist) {
        self.tracklist = tracklist
        self.isPersisted = tracklist.isPersisted

        if tracklist.mediaSourceId == "boppa.app" {
            self.observers.append(
                NotificationCenter.default.addObserver(
                    forName: .playlistMembershipChanged,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    guard let self else { return }
                    if let stored = TracklistStorageManager.shared.findStoredTracklist(
                        mediaId: self.tracklist.mediaId,
                        mediaSourceId: self.tracklist.mediaSourceId
                    ) {
                        self.loadFromCache(storedTracklist: stored)
                    }
                }
            )
        }
    }

    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    var displayTracks: [Track] {
        var base = self.tracks
        if self.tracklist.mediaSourceId == "boppa.app" {
            base = base.filter {
                PlaylistManager.shared.isInPlaylist($0, playlistId: self.tracklist.mediaId)
            }
        }
        let items = self.searchHandler.displayItems(from: base)
        if self.searchHandler.filteredItems != nil {
            return items
        }
        return self.applySorting(items)
    }

    func updateSearch(_ text: String) {
        self.searchHandler.updateSearch(text, items: self.tracks)
    }

    var canRefresh: Bool {
        self.isPersisted
    }

    func load() {
        let stored = self.tracklist.storedTracklist
            ?? TracklistStorageManager.shared.findStoredTracklist(mediaId: self.tracklist.mediaId, mediaSourceId: self.tracklist.mediaSourceId)

        if self.tracklist.tracklistType == .album || self.tracklist.tracklistType == .playlist, stored?.isSavedToLibrary != true {
            RecentsStorageManager.shared.recordViewedTracklist(self.tracklist)
        }

        if let stored, stored.isSavedToLibrary {
            self.tracklist = TracklistStorageManager.shared.tracklistWithRelations(from: stored)
            self.isPersisted = true
            self.isPinned = stored.isPinned
            self.loadFromCache(storedTracklist: stored)
        }

        if self.tracks.isEmpty {
            self.fetchFirstPage()
        }
    }

    func refresh() {
        guard self.isPersisted else { return }
        self.isRefreshing = true

        Task {
            do {
                if let meta = try await TracklistFetchService.shared.fetchTracklistMetadata(tracklist: self.tracklist) {
                    self.tracklist = Tracklist(
                        mediaId: self.tracklist.mediaId,
                        mediaSourceId: self.tracklist.mediaSourceId,
                        title: meta.title.isEmpty ? self.tracklist.title : meta.title,
                        subtitle: meta.subtitle ?? self.tracklist.subtitle,
                        year: meta.year ?? self.tracklist.year,
                        trackCount: meta.trackCount ?? self.tracklist.trackCount,
                        artworkUrl: meta.artworkUrl ?? self.tracklist.artworkUrl,
                        url: meta.url ?? self.tracklist.url,
                        tracklistType: self.tracklist.tracklistType,
                        storedTracklist: self.tracklist.storedTracklist
                    )
                }

                let tracks = try await TracklistFetchService.shared.fetchAllTracks(
                    for: self.tracklist,
                    onPageFetched: { [weak self] allTracksSoFar in
                        guard let self else { return }
                        self.unsortedTracks = allTracksSoFar
                        self.tracks = allTracksSoFar
                        self.hasMorePages = false
                    }
                )
                _ = try await TracklistStorageManager.shared.storeTracklist(self.tracklist, tracks: tracks)

                self.isRefreshing = false

                logger.info("Refreshed tracklist '\(self.tracklist.title)' with \(self.tracks.count) track(s)")
            } catch {
                self.isRefreshing = false
                self.errorMessage = error.localizedDescription
                logger.error("Refresh failed for '\(self.tracklist.title)': \(error.localizedDescription)")
            }
        }
    }

    func setSortMode(_ mode: SortMode) {
        if self.sortMode == mode {
            self.sortMode = .defaultOrder
        } else {
            self.sortMode = mode
        }
    }

    private func loadFromCache(storedTracklist: StoredTracklist) {
        self.unsortedTracks = TracklistStorageManager.shared.loadTracksForTracklist(storedTracklist)
        self.tracks = self.unsortedTracks
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

    private func fetchFirstPage() {
        self.fetchTask?.cancel()
        self.isLoading = true
        self.errorMessage = nil

        self.fetchTask = Task {
            do {
                let response = try await TracklistFetchService.shared.fetchTracklist(
                    tracklist: self.tracklist,
                    previousResult: nil
                )
                guard !Task.isCancelled else { return }
                self.unsortedTracks = response.tracks
                self.tracks = response.tracks
                self.continuation = response.tracks.isEmpty ? nil : response.continuation
                self.hasMorePages = !response.tracks.isEmpty && response.continuation != nil

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

    func saveToLibrary() {
        guard !self.isSaving else { return }
        self.isSaving = true
        self.fetchTask?.cancel()

        Task {
            do {
                if let meta = try await TracklistFetchService.shared.fetchTracklistMetadata(tracklist: self.tracklist) {
                    self.tracklist = Tracklist(
                        mediaId: self.tracklist.mediaId,
                        mediaSourceId: self.tracklist.mediaSourceId,
                        title: meta.title,
                        subtitle: meta.subtitle,
                        year: meta.year,
                        trackCount: meta.trackCount,
                        artworkUrl: meta.artworkUrl,
                        url: meta.url,
                        tracklistType: self.tracklist.tracklistType,
                        storedTracklist: self.tracklist.storedTracklist
                    )
                }

                let tracks = try await TracklistFetchService.shared.fetchAllTracks(
                    for: self.tracklist,
                    onPageFetched: { [weak self] allTracksSoFar in
                        guard let self else { return }
                        self.unsortedTracks = allTracksSoFar
                        self.tracks = allTracksSoFar
                        self.hasMorePages = false
                    }
                )
                let stored = try await TracklistStorageManager.shared.storeTracklist(self.tracklist, tracks: tracks)

                self.tracklist = TracklistStorageManager.shared.tracklistWithRelations(from: stored)
                self.isPersisted = true
                self.isSaving = false
                NotificationCenter.default.post(name: .tracklistLibraryChanged, object: nil)
                logger.info("Saved tracklist '\(self.tracklist.title)' to library")
            } catch {
                self.isSaving = false
                self.errorMessage = error.localizedDescription
                logger.error("Failed to save tracklist '\(self.tracklist.title)': \(error.localizedDescription)")
            }
        }
    }

    func deleteFromLibrary() {
        guard let stored = self.tracklist.storedTracklist else { return }
        try? TracklistStorageManager.shared.deleteStoredTracklist(stored)
        self.isPersisted = false
        NotificationCenter.default.post(name: .tracklistLibraryChanged, object: nil)
        logger.info("Deleted tracklist '\(self.tracklist.title)' from library")
    }

    func togglePin() {
        guard let stored = self.tracklist.storedTracklist else { return }
        let newIsPinned = !self.isPinned
        try? TracklistStorageManager.shared.setPin(stored, isPinned: newIsPinned)
        self.isPinned = newIsPinned
        NotificationCenter.default.post(name: .tracklistPinChanged, object: nil)
        logger.info("\(newIsPinned ? "Pinned" : "Unpinned") tracklist '\(self.tracklist.title)'")
    }

    func loadNextPage() {
        guard let continuation = self.continuation,
              !self.isLoading
        else {
            return
        }

        self.isLoading = true

        Task {
            do {
                let response = try await TracklistFetchService.shared.fetchTracklist(
                    tracklist: self.tracklist,
                    previousResult: continuation
                )

                guard !Task.isCancelled else { return }

                self.unsortedTracks.append(contentsOf: response.tracks)
                self.tracks = self.unsortedTracks
                self.continuation = response.continuation
                self.hasMorePages = response.continuation != nil
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
