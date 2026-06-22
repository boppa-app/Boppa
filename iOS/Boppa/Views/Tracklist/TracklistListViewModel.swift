import Foundation
import os
import SwiftUI

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "Boppa",
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
    var isEditing = false

    let searchHandler = FuzzySearchHandler<Tracklist>()

    private var fetchTask: Task<Void, Never>?
    private var didLoad = false
    private var libraryType: TracklistListType?

    @ObservationIgnored
    private var observers: [NSObjectProtocol] = []

    init() {
        self.observers.append(
            NotificationCenter.default.addObserver(
                forName: .tracklistLibraryChanged,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let self, let type = self.libraryType else { return }
                self.reloadFromLibrary(type: type)
            }
        )
        for name: Notification.Name in [.mediaSourceDisabled, .mediaSourceRemoved, .mediaSourceEnabled, .mediaSourceAdded] {
            self.observers.append(
                NotificationCenter.default.addObserver(
                    forName: name,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    guard let self, let type = self.libraryType else { return }
                    self.reloadFromLibrary(type: type)
                }
            )
        }
    }

    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    var displayTracklists: [Tracklist] {
        if self.isEditing {
            return self.tracklists
        }
        let items = self.searchHandler.displayItems(from: self.tracklists)
        if self.searchHandler.filteredItems != nil {
            return items
        }
        return self.applySorting(items)
    }

    func updateSearch(_ text: String) {
        self.searchHandler.updateSearch(text, items: self.tracklists)
    }

    func setSortMode(_ mode: SortMode, type: TracklistListType) {
        if self.sortMode == mode {
            self.sortMode = .defaultOrder
        } else {
            self.sortMode = mode
        }
        UserDefaults.standard.set(self.sortMode.rawValue, forKey: Self.sortModeKey(for: type))
    }

    func loadSortMode(type: TracklistListType) {
        if let raw = UserDefaults.standard.string(forKey: Self.sortModeKey(for: type)),
           let mode = SortMode(rawValue: raw)
        {
            self.sortMode = mode
        }
    }

    private static func sortModeKey(for type: TracklistListType) -> String {
        switch type {
        case .albums: return "tracklistListSortMode.albums"
        case .playlists: return "tracklistListSortMode.playlists"
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

    func enterEditMode(type: TracklistListType) {
        self.sortMode = .defaultOrder
        UserDefaults.standard.set(SortMode.defaultOrder.rawValue, forKey: Self.sortModeKey(for: type))
        self.isEditing = true
    }

    func exitEditMode() {
        self.isEditing = false
    }

    func deleteTracklistById(_ id: UUID) {
        guard let index = self.tracklists.firstIndex(where: { $0.id == id }) else { return }
        let tracklist = self.tracklists[index]
        if let stored = tracklist.storedTracklist {
            try? TracklistStorageManager.shared.deleteStoredTracklist(stored)
        }
        self.tracklists.remove(at: index)
        NotificationCenter.default.post(name: .tracklistLibraryChanged, object: nil)
    }

    func moveTracklist(from source: IndexSet, to destination: Int) {
        self.tracklists.move(fromOffsets: source, toOffset: destination)
        self.persistAllSortOrders()
    }

    func togglePin(tracklist: Tracklist) {
        guard let stored = tracklist.storedTracklist else { return }
        let newIsPinned = !stored.isPinned
        try? TracklistStorageManager.shared.setPin(stored, isPinned: newIsPinned)
        if let index = self.tracklists.firstIndex(where: { $0.id == tracklist.id }) {
            var updatedStored = stored
            updatedStored.isPinned = newIsPinned
            self.tracklists[index] = Tracklist(
                storedTracklist: updatedStored,
                fromArtist: tracklist.fromArtist
            )
        }
        NotificationCenter.default.post(name: .tracklistPinChanged, object: nil)
        logger.info("\(newIsPinned ? "Pinned" : "Unpinned") tracklist '\(stored.title)'")
    }

    private func persistAllSortOrders() {
        try? TracklistStorageManager.shared.updateSortOrders(
            for: self.tracklists,
            reversed: self.libraryType == .albums
        )
    }

    func loadFromArtist(
        type: TracklistListType,
        artist: Artist,
        mediaSource: MediaSource
    ) {
        guard !self.didLoad else { return }
        self.didLoad = true
        switch type {
        case .albums:
            self.fetchAlbums(artist: artist, mediaSource: mediaSource)
        case .playlists:
            self.fetchPlaylists(artist: artist, mediaSource: mediaSource)
        }
    }

    func loadFromLibrary(type: TracklistListType) {
        self.libraryType = type
        self.reloadFromLibrary(type: type)
    }

    private func reloadFromLibrary(type: TracklistListType) {
        let typeString = type == .albums ? "album" : "playlist"
        self.tracklists = TracklistStorageManager.shared.loadLibraryTracklists(
            type: typeString,
            reversed: type == .albums
        )
        logger.info("Loaded \(self.tracklists.count) \(typeString)(s) from library")
    }

    private func fetchAlbums(
        artist: Artist,
        mediaSource: MediaSource
    ) {
        self.fetchTask?.cancel()
        self.isLoading = true
        self.errorMessage = nil

        self.fetchTask = Task {
            do {
                let result = try await TracklistFetchService.shared.fetchAlbumsForArtist(
                    artist: artist,
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
        mediaSource: MediaSource
    ) {
        self.fetchTask?.cancel()
        self.isLoading = true
        self.errorMessage = nil

        self.fetchTask = Task {
            do {
                let result = try await TracklistFetchService.shared.fetchPlaylistsForArtist(
                    artist: artist,
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
