import Foundation
import os

@MainActor
@Observable
class LibraryViewModel {
    var mediaSources: [MediaSource] = []
    var isPinnedExpanded = false
    private var allPinnedTracklists: [StoredTracklist] = []
    private var hasSetInitialPinnedState = false

    var searchQuery: String = ""
    var selectedLibraryCategory: SearchCategory = .songs
    private(set) var availableLibraryCategories: [SearchCategory] = []
    private var allLibraryTracks: [StoredTrack] = []
    private var allLibraryTracklists: [StoredTracklist] = []

    var pinnedTracklists: [StoredTracklist] {
        self.allPinnedTracklists
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
        self.mediaSources = MediaSourceStorageManager.shared.fetchAll()
        self.loadPinnedTracklists()
        self.loadAllContent()
    }

    func loadPinnedTracklists() {
        self.allPinnedTracklists = TracklistStorageManager.shared.fetchPinnedTracklists()
        if !self.hasSetInitialPinnedState {
            self.hasSetInitialPinnedState = true
            self.isPinnedExpanded = !self.pinnedTracklists.isEmpty
        }
    }

    private var songSourceIds: Set<String> {
        Set(self.mediaSources.filter { $0.config.data.search?.songs != nil }.map(\.id))
    }

    private var videoSourceIds: Set<String> {
        Set(self.mediaSources.filter { $0.config.data.search?.videos != nil }.map(\.id))
    }

    var categoryFilteredTracks: [StoredTrack] {
        switch self.selectedLibraryCategory {
        case .songs:
            let ids = self.songSourceIds
            return self.allLibraryTracks.filter { ids.contains($0.mediaSourceId) }
        case .videos:
            let ids = self.videoSourceIds
            return self.allLibraryTracks.filter { ids.contains($0.mediaSourceId) }
        default:
            return []
        }
    }

    var categoryFilteredTracklists: [StoredTracklist] {
        switch self.selectedLibraryCategory {
        case .albums:
            return self.allLibraryTracklists.filter { $0.tracklistType == "album" }
        case .playlists:
            return self.allLibraryTracklists.filter { $0.tracklistType == "playlist" }
        default:
            return []
        }
    }

    func loadAllContent() {
        self.allLibraryTracks = TrackStorageManager.shared.fetchLibraryTracks()
        self.allLibraryTracklists = TracklistStorageManager.shared.fetchLibraryTracklists()
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
