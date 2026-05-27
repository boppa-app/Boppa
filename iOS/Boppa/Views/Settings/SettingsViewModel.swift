import Dependencies
import Foundation
import SQLiteData

@MainActor
@Observable
class SettingsViewModel {
    var mediaSources: [MediaSource] = []

    @ObservationIgnored
    @Dependency(\.defaultDatabase) var database

    func loadSources() {
        self.mediaSources = (try? database.read { db in
            try MediaSource.order { $0.sortOrder }.fetchAll(db)
        }) ?? []
    }

    func moveMediaSource(from sourceIndex: Int, to destinationIndex: Int) {
        var reordered = self.mediaSources
        let item = reordered.remove(at: sourceIndex)
        reordered.insert(item, at: destinationIndex)
        try? database.write { db in
            for (index, mediaSource) in reordered.enumerated() {
                try MediaSource.update { $0.sortOrder = index }
                    .where { $0.id.eq(mediaSource.id) }
                    .execute(db)
            }
        }
        self.mediaSources = reordered
    }

    func deleteMediaSource(at index: Int) -> String {
        let mediaSource = self.mediaSources[index]
        let deletedId = mediaSource.id
        try? database.write { db in
            try MediaSource.where { $0.id.eq(mediaSource.id) }.delete().execute(db)
        }
        self.mediaSources.remove(at: index)
        return deletedId
    }
}
