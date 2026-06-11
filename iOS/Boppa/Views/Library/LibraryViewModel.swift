import Dependencies
import Foundation
import os
import SQLiteData

@MainActor
@Observable
class LibraryViewModel {
    var mediaSources: [MediaSource] = []
    var visibleMediaSourceIds: Set<String> = []
    var showFilterSheet = false
    var isPinnedExpanded = false
    private var allPinnedTracklists: [StoredTracklist] = []
    private var hasSetInitialPinnedState = false

    var searchQuery: String = ""
    var selectedLibraryCategory: SearchCategory = .songs
    private(set) var availableLibraryCategories: [SearchCategory] = []
    private var allLibraryTracks: [StoredTrack] = []
    private var allLibraryTracklists: [StoredTracklist] = []

    @ObservationIgnored
    @Dependency(\.defaultDatabase) var database

    var pinnedTracklists: [StoredTracklist] {
        let visibleIds = self.visibleMediaSourceStringIds
        return self.allPinnedTracklists.filter { visibleIds.contains($0.mediaSourceId) }
    }

    enum LibrarySection: String, CaseIterable {
        case likes
        case playlists = "playlist"
        case albums = "album"

        var displayName: String {
            switch self {
            case .likes: return "Likes"
            case .playlists: return "Playlists"
            case .albums: return "Albums"
            }
        }

        var icon: String {
            switch self {
            case .likes: return "heart.fill"
            case .playlists: return "music.note.list"
            case .albums:
                if #available(iOS 26.0, *) {
                    return "music.note.square.stack.fill"
                } else {
                    return "square.stack.fill"
                }
            }
        }
    }

    func loadSources() {
        let newSources = (try? self.database.read { db in
            try MediaSource.where(\.isEnabled).order { $0.sortOrder }.fetchAll(db)
        }) ?? []

        let oldIds = Set(self.mediaSources.map(\.id))
        self.mediaSources = newSources
        let newIds = Set(newSources.map(\.id))

        let added = newIds.subtracting(oldIds)
        let removed = oldIds.subtracting(newIds)

        self.visibleMediaSourceIds.formUnion(added)
        self.visibleMediaSourceIds.subtract(removed)

        if oldIds.isEmpty {
            self.visibleMediaSourceIds = newIds
        }

        self.loadPinnedTracklists()
        self.loadAllContent()
    }

    func loadPinnedTracklists() {
        self.allPinnedTracklists = (try? self.database.read { db in
            try StoredTracklist.where(\.isPinned).fetchAll(db)
        }) ?? []
        if !self.hasSetInitialPinnedState {
            self.hasSetInitialPinnedState = true
            self.isPinnedExpanded = !self.pinnedTracklists.isEmpty
        }
    }

    var filteredSources: [MediaSource] {
        self.mediaSources.filter { self.visibleMediaSourceIds.contains($0.id) }
    }

    var visibleMediaSourceStringIds: Set<String> {
        Set(self.filteredSources.map(\.id))
    }

    private var songSourceIds: Set<String> {
        Set(self.mediaSources.filter { $0.config.data?.searchSongs != nil }.map(\.id))
    }

    private var videoSourceIds: Set<String> {
        Set(self.mediaSources.filter { $0.config.data?.searchVideos != nil }.map(\.id))
    }

    var categoryFilteredTracks: [StoredTrack] {
        let visibleIds = self.visibleMediaSourceStringIds
        switch self.selectedLibraryCategory {
        case .songs:
            let ids = self.songSourceIds
            return self.allLibraryTracks.filter { visibleIds.contains($0.mediaSourceId) && ids.contains($0.mediaSourceId) }
        case .videos:
            let ids = self.videoSourceIds
            return self.allLibraryTracks.filter { visibleIds.contains($0.mediaSourceId) && ids.contains($0.mediaSourceId) }
        default:
            return []
        }
    }

    var categoryFilteredTracklists: [StoredTracklist] {
        let visibleIds = self.visibleMediaSourceStringIds
        switch self.selectedLibraryCategory {
        case .albums:
            return self.allLibraryTracklists.filter { visibleIds.contains($0.mediaSourceId) && $0.tracklistType == "album" }
        case .playlists:
            return self.allLibraryTracklists.filter { visibleIds.contains($0.mediaSourceId) && $0.tracklistType == "playlist" }
        default:
            return []
        }
    }

    func loadAllContent() {
        self.allLibraryTracks = (try? self.database.read { db in
            try StoredTrack.fetchAll(db)
        }) ?? []
        self.allLibraryTracklists = (try? self.database.read { db in
            try StoredTracklist.where(\.isSavedToLibrary).fetchAll(db)
        }) ?? []
        self.updateAvailableCategories()
    }

    func updateAvailableCategories() {
        let songIds = self.songSourceIds
        let videoIds = self.videoSourceIds

        let hasSongs = self.allLibraryTracks.contains { songIds.contains($0.mediaSourceId) }
        let hasVideos = self.allLibraryTracks.contains { videoIds.contains($0.mediaSourceId) }
        let hasAlbums = self.allLibraryTracklists.contains { $0.tracklistType == "album" }
        let hasPlaylists = self.allLibraryTracklists.contains { $0.tracklistType == "playlist" }

        var categories: [SearchCategory] = []
        if hasSongs { categories.append(.songs) }
        if hasVideos { categories.append(.videos) }
        if hasAlbums { categories.append(.albums) }
        if hasPlaylists { categories.append(.playlists) }

        self.availableLibraryCategories = categories

        if !categories.contains(self.selectedLibraryCategory), let first = categories.first {
            self.selectedLibraryCategory = first
        }
    }
}
