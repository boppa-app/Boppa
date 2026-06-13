import Dependencies
import Foundation
import os
import SQLiteData

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Boppa", category: "MediaSourceStorageManager")

class MediaSourceStorageManager {
    static let shared = MediaSourceStorageManager()

    @Dependency(\.defaultDatabase) var database

    private init() {}

    // MARK: - Reads

    func fetchAll() -> [MediaSource] {
        (try? self.database.read { db in
            try MediaSource.order { $0.sortOrder }.fetchAll(db)
        }) ?? []
    }

    func fetchAllEnabled() -> [MediaSource] {
        (try? self.database.read { db in
            try MediaSource.where(\.isEnabled).order { $0.sortOrder }.fetchAll(db)
        }) ?? []
    }

    func fetchOne(id: String) -> MediaSource? {
        try? self.database.read { db in
            try MediaSource.where { $0.id.eq(id) }.fetchOne(db)
        }
    }

    // MARK: - Writes

    func insert(_ mediaSources: [MediaSource]) throws {
        try self.database.write { db in
            let maxKey = try MediaSource.order { $0.sortOrder.desc() }.fetchOne(db)?.sortOrder
            var prevKey = maxKey
            for var mediaSource in mediaSources {
                let newKey = FractionalIndex.generateKeyBetween(prevKey, nil)
                mediaSource.sortOrder = newKey
                prevKey = newKey
                try MediaSource.insert { mediaSource }.execute(db)
            }
        }
        logger.info("Inserted \(mediaSources.count) media source(s)")
    }

    func setEnabled(id: String, isEnabled: Bool) throws {
        try self.database.write { db in
            try MediaSource.update { $0.isEnabled = isEnabled }
                .where { $0.id.eq(id) }
                .execute(db)
        }
    }

    func updateSortOrders(_ mediaSources: [MediaSource]) throws -> [MediaSource] {
        let newKeys = FractionalIndex.generateNKeysBetween(nil, nil, n: mediaSources.count)
        try self.database.write { db in
            for (mediaSource, key) in zip(mediaSources, newKeys) {
                try MediaSource.update { $0.sortOrder = key }
                    .where { $0.id.eq(mediaSource.id) }
                    .execute(db)
            }
        }
        return zip(mediaSources, newKeys).map { mediaSource, key in
            var updated = mediaSource
            updated.sortOrder = key
            return updated
        }
    }

    func delete(id: String) throws {
        try self.database.write { db in
            try MediaSource.where { $0.id.eq(id) }.delete().execute(db)
        }
        logger.info("Deleted media source '\(id)'")
    }

    func mergeContextValues(id: String, newValues: [String: Any]) throws {
        try self.database.write { db in
            let mediaSource = try MediaSource.where { $0.id.eq(id) }.fetchOne(db)
            guard let mediaSource else {
                logger.warning("Could not find MediaSource '\(id)' to store context values")
                return
            }
            var contextValues = mediaSource.contextValues
            for (key, value) in newValues {
                if let stringValue = value as? String {
                    contextValues[key] = stringValue
                } else {
                    contextValues[key] = String(describing: value)
                }
            }
            let json = (try? JSONEncoder().encode(contextValues)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
            try MediaSource.update { $0.contextValuesJSON = json }
                .where { $0.id.eq(id) }
                .execute(db)
        }
    }
}
