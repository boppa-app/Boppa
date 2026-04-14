import Foundation
import os
import SwiftData

@MainActor
@Observable
class LibraryViewModel {
    var mediaSources: [MediaSource] = []
    var collapsedSections: Set<String> = []
    var visibleSourceIDs: Set<PersistentIdentifier> = []
    var showFilterSheet = false

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
        self.mediaSources = (try? modelContext.fetch(descriptor)) ?? []

        let enabledIDs = Set(self.mediaSources.map(\.persistentModelID))
        self.visibleSourceIDs = self.visibleSourceIDs.isEmpty
            ? enabledIDs
            : self.visibleSourceIDs.intersection(enabledIDs)
    }

    func toggleCollapse(section: String) {
        if self.collapsedSections.contains(section) {
            self.collapsedSections.remove(section)
        } else {
            self.collapsedSections.insert(section)
        }
    }

    func isCollapsed(section: String) -> Bool {
        self.collapsedSections.contains(section)
    }

    func tracklistsForSection(_ section: LibrarySection, modelContext: ModelContext) -> [(StoredTracklist, MediaSource)] {
        let typeString = section.rawValue
        let descriptor = FetchDescriptor<StoredTracklist>(
            predicate: #Predicate { $0.tracklistType == typeString }
        )

        let tracklists = (try? modelContext.fetch(descriptor)) ?? []
        let visibleSourceNames = Set(self.filteredSources.map(\.name))
        let sourcesByName = Dictionary(uniqueKeysWithValues: self.mediaSources.map { ($0.name, $0) })

        return tracklists
            .filter { visibleSourceNames.contains($0.mediaSourceName) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .compactMap { tracklist in
                guard let source = sourcesByName[tracklist.mediaSourceName] else { return nil }
                return (tracklist, source)
            }
    }

    var filteredSources: [MediaSource] {
        self.mediaSources.filter { self.visibleSourceIDs.contains($0.persistentModelID) }
    }
}
