import Foundation
import os
import SwiftData

@MainActor
@Observable
class LibraryViewModel {
    var mediaSources: [MediaSource] = []
    var visibleMediaSourceIds: Set<PersistentIdentifier> = []
    var showFilterSheet = false
    var pinnedTracklists: [StoredTracklist] = []
    var isPinnedExpanded = false
    private var hasSetInitialPinnedState = false

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

    func loadSources(modelContext: ModelContext) {
        var descriptor = FetchDescriptor<MediaSource>(
            predicate: #Predicate { $0.isEnabled }
        )
        descriptor.sortBy = [SortDescriptor(\MediaSource.order)]

        let oldIds = Set(self.mediaSources.map(\.persistentModelID))
        self.mediaSources = (try? modelContext.fetch(descriptor)) ?? []
        let newIds = Set(self.mediaSources.map(\.persistentModelID))

        let added = newIds.subtracting(oldIds)
        let removed = oldIds.subtracting(newIds)

        self.visibleMediaSourceIds.formUnion(added)
        self.visibleMediaSourceIds.subtract(removed)

        if oldIds.isEmpty {
            self.visibleMediaSourceIds = newIds
        }

        self.loadPinnedTracklists(modelContext: modelContext)
    }

    func loadPinnedTracklists(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<StoredTracklist>(
            predicate: #Predicate { $0.isPinned }
        )
        self.pinnedTracklists = (try? modelContext.fetch(descriptor)) ?? []
        if !self.hasSetInitialPinnedState {
            self.hasSetInitialPinnedState = true
            self.isPinnedExpanded = !self.pinnedTracklists.isEmpty
        }
    }

    var filteredSources: [MediaSource] {
        self.mediaSources.filter { self.visibleMediaSourceIds.contains($0.persistentModelID) }
    }

    var visibleMediaSourceStringIds: Set<String> {
        Set(self.filteredSources.map(\.id))
    }
}
