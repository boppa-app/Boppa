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

    func fetchAll() -> [StoredMediaSource] {
        (try? self.database.read { db in
            try StoredMediaSource.order { $0.sortOrder }.fetchAll(db)
        }) ?? []
    }

    func fetchAllEnabled() -> [StoredMediaSource] {
        let all = (try? self.database.read { db in
            try StoredMediaSource.where(\.isEnabled).order { $0.sortOrder }.fetchAll(db)
        }) ?? []
        return all.filter { $0.isContextGathered }
    }

    func fetchOne(id: String) -> StoredMediaSource? {
        try? self.database.read { db in
            try StoredMediaSource.where { $0.id.eq(id) }.fetchOne(db)
        }
    }

    // MARK: - Writes

    func insert(_ mediaSources: [StoredMediaSource]) throws {
        try self.database.write { db in
            let maxKey = try StoredMediaSource.order { $0.sortOrder.desc() }.fetchOne(db)?.sortOrder
            var prevKey = maxKey
            for var mediaSource in mediaSources {
                let newKey = FractionalIndex.generateKeyBetween(prevKey, nil)
                mediaSource.sortOrder = newKey
                prevKey = newKey
                try StoredMediaSource.insert { mediaSource }.execute(db)
            }
        }
        logger.info("Inserted \(mediaSources.count) media source(s)")
    }

    func updateConfig(id: String, configData: Data) throws {
        let now = Date().timeIntervalSince1970
        try self.database.write { db in
            try StoredMediaSource.update {
                $0.configData = #bind(configData)
                $0.lastUpdatedTimestamp = #bind(now)
            }
            .where { $0.id.eq(id) }
            .execute(db)
        }
        logger.info("Updated config for '\(id)'")
    }

    func setAutoUpdate(id: String, autoUpdate: Bool) throws {
        try self.database.write { db in
            try StoredMediaSource.update { $0.autoUpdate = autoUpdate }
                .where { $0.id.eq(id) }
                .execute(db)
        }
    }

    func setEnabled(id: String, isEnabled: Bool) throws {
        try self.database.write { db in
            try StoredMediaSource.update { $0.isEnabled = isEnabled }
                .where { $0.id.eq(id) }
                .execute(db)
        }
    }

    func updateSortOrders(_ mediaSources: [StoredMediaSource]) throws -> [StoredMediaSource] {
        let newKeys = FractionalIndex.generateNKeysBetween(nil, nil, n: mediaSources.count)
        try self.database.write { db in
            for (mediaSource, key) in zip(mediaSources, newKeys) {
                try StoredMediaSource.update { $0.sortOrder = key }
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
            try StoredMediaSource.where { $0.id.eq(id) }.delete().execute(db)
        }
        logger.info("Deleted media source '\(id)'")
    }

    func setContextLastGatheredTimestamp(id: String) throws -> Bool {
        var wasNil = false
        try self.database.write { db in
            let mediaSource = try StoredMediaSource.where { $0.id.eq(id) }.fetchOne(db)
            guard let mediaSource else { return }
            wasNil = mediaSource.contextLastGatheredTimestamp == nil
            let now = Date().timeIntervalSince1970
            try StoredMediaSource.update { $0.contextLastGatheredTimestamp = #bind(now) }
                .where { $0.id.eq(id) }
                .execute(db)
        }
        return wasNil
    }

    func mergeContextValues(id: String, newValues: [String: Any]) throws {
        try self.database.write { db in
            let mediaSource = try StoredMediaSource.where { $0.id.eq(id) }.fetchOne(db)
            guard let mediaSource else {
                logger.warning("Could not find StoredMediaSource '\(id)' to store context values")
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
            try StoredMediaSource.update { $0.contextValuesJSON = json }
                .where { $0.id.eq(id) }
                .execute(db)
        }
    }
}
