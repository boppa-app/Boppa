import Dependencies
import Foundation
import os
import SQLiteData
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

    @ObservationIgnored
    @Dependency(\.defaultDatabase) var database

    let searchHandler = FuzzySearchHandler<Tracklist>()

    private var fetchTask: Task<Void, Never>?
    private var didLoad = false

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
            try? database.write { db in
                if let prevId = stored.prevId {
                    try StoredTracklist.update { $0.nextId = stored.nextId }
                        .where { $0.id.eq(prevId) }
                        .execute(db)
                }
                if let nextId = stored.nextId {
                    try StoredTracklist.update { $0.prevId = stored.prevId }
                        .where { $0.id.eq(nextId) }
                        .execute(db)
                }
                try StoredTracklist.where { $0.id.eq(stored.id) }.delete().execute(db)
            }
        }
        self.tracklists.remove(at: index)
    }

    func moveTracklist(from source: IndexSet, to destination: Int) {
        self.tracklists.move(fromOffsets: source, toOffset: destination)
        self.persistDLLOrder()
    }

    func togglePin(tracklist: Tracklist) {
        guard let stored = tracklist.storedTracklist else { return }
        let newIsPinned = !stored.isPinned
        try? database.write { db in
            try StoredTracklist.update { $0.isPinned = newIsPinned }
                .where { $0.id.eq(stored.id) }
                .execute(db)
        }
        if let index = self.tracklists.firstIndex(where: { $0.id == tracklist.id }) {
            var updatedStored = stored
            updatedStored.isPinned = newIsPinned
            self.tracklists[index] = Tracklist(storedTracklist: updatedStored)
        }
        NotificationCenter.default.post(name: .tracklistPinChanged, object: nil)
        logger.info("\(newIsPinned ? "Pinned" : "Unpinned") tracklist '\(stored.name)'")
    }

    private func persistDLLOrder() {
        try? database.write { db in
            for (index, tracklist) in self.tracklists.enumerated() {
                guard let stored = tracklist.storedTracklist else { continue }
                let prevId = index > 0 ? self.tracklists[index - 1].storedTracklist?.id : nil
                let nextId = index < self.tracklists.count - 1 ? self.tracklists[index + 1].storedTracklist?.id : nil
                try StoredTracklist.update {
                    $0.prevId = prevId
                    $0.nextId = nextId
                }
                .where { $0.id.eq(stored.id) }
                .execute(db)
            }
        }
    }

    func loadFromArtist(
        type: TracklistListType,
        artist: Artist,
        artistDetail: ArtistDetail,
        mediaSource: MediaSource
    ) {
        guard !self.didLoad else { return }
        self.didLoad = true
        switch type {
        case .albums:
            self.fetchAlbums(artist: artist, artistDetail: artistDetail, mediaSource: mediaSource)
        case .playlists:
            self.fetchPlaylists(artist: artist, artistDetail: artistDetail, mediaSource: mediaSource)
        }
    }

    func loadFromLibrary(type: TracklistListType, visibleMediaSourceIds: Set<String>) {
        let typeString: String
        switch type {
        case .albums: typeString = "album"
        case .playlists: typeString = "playlist"
        }

        let allStored = (try? database.read { db in
            try StoredTracklist.where { $0.tracklistType.eq(typeString) }.fetchAll(db)
        }) ?? []

        let filtered = allStored.filter { visibleMediaSourceIds.contains($0.mediaSourceId) }
        let lookup = Dictionary(uniqueKeysWithValues: filtered.map { ($0.id, $0) })
        var ordered: [StoredTracklist] = []

        if let head = filtered.first(where: { $0.prevId == nil }) {
            var current: StoredTracklist? = head
            while let node = current {
                ordered.append(node)
                current = node.nextId.flatMap { lookup[$0] }
            }
        }

        let orderedIds = Set(ordered.map { $0.id })
        for item in filtered where !orderedIds.contains(item.id) {
            ordered.append(item)
        }

        self.tracklists = ordered.map { Tracklist(storedTracklist: $0) }
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
