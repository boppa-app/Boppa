import Dependencies
import Foundation
import SQLiteData
import SwiftUI

@MainActor
@Observable
class SettingsViewModel {
    var mediaSources: [MediaSource] = []

    @ObservationIgnored
    @Dependency(\.defaultDatabase) var database

    func loadSources() {
        self.mediaSources = (try? self.database.read { db in
            try MediaSource.order { $0.sortOrder }.fetchAll(db)
        }) ?? []
    }

    func moveMediaSources(from source: IndexSet, to destination: Int) {
        var reordered = self.mediaSources
        reordered.move(fromOffsets: source, toOffset: destination)
        let newKeys = FractionalIndex.generateNKeysBetween(nil, nil, n: reordered.count)
        try? self.database.write { db in
            for (mediaSource, key) in zip(reordered, newKeys) {
                try MediaSource.update { $0.sortOrder = key }
                    .where { $0.id.eq(mediaSource.id) }
                    .execute(db)
            }
        }
        self.mediaSources = zip(reordered, newKeys).map { mediaSource, key in
            var updated = mediaSource
            updated.sortOrder = key
            return updated
        }
    }

    func deleteMediaSources(at offsets: IndexSet) -> [String] {
        var deletedIds: [String] = []
        for index in offsets.sorted().reversed() {
            let mediaSource = self.mediaSources[index]
            deletedIds.append(mediaSource.id)
            try? self.database.write { db in
                try MediaSource.where { $0.id.eq(mediaSource.id) }.delete().execute(db)
            }
            self.mediaSources.remove(at: index)
        }
        return deletedIds
    }
}
