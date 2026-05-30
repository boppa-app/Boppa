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
}
