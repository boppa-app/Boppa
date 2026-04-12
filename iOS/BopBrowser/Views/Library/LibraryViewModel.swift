import Foundation
import os
import SwiftData

@MainActor
@Observable
class LibraryViewModel {
    var mediaSources: [MediaSource] = []
    var collapsedSources: Set<String> = []
    var visibleSourceIDs: Set<PersistentIdentifier> = []
    var showFilterSheet = false

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

        for source in self.mediaSources where self.hasLikesScript(source) {
            _ = TracklistService.shared.ensureLikesPlaylist(
                mediaSourceName: source.name,
                modelContext: modelContext
            )
        }
    }

    func toggleCollapse(sourceName: String) {
        if self.collapsedSources.contains(sourceName) {
            self.collapsedSources.remove(sourceName)
        } else {
            self.collapsedSources.insert(sourceName)
        }
    }

    func isCollapsed(sourceName: String) -> Bool {
        self.collapsedSources.contains(sourceName)
    }

    func playlistsForSource(_ source: MediaSource, modelContext: ModelContext) -> [StoredTracklist] {
        let name = source.name
        let descriptor = FetchDescriptor<StoredTracklist>(
            predicate: #Predicate { $0.mediaSourceName == name }
        )

        var playlists = (try? modelContext.fetch(descriptor)) ?? []

        if !self.hasLikesScript(source) {
            playlists.removeAll { $0.isLikes }
        }

        return playlists.sorted { a, b in
            if a.isLikes, !b.isLikes { return true }
            if !a.isLikes, b.isLikes { return false }
            return a.name < b.name
        }
    }

    var filteredSources: [MediaSource] {
        self.mediaSources.filter { self.visibleSourceIDs.contains($0.persistentModelID) }
    }

    func hasLikesScript(_ source: MediaSource) -> Bool {
        source.config.data?.listLikes != nil
    }
}
