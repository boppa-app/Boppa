import Dependencies
import Foundation
import SQLiteData

class FractionalIndexKeyQueries {
    static let shared = FractionalIndexKeyQueries()

    @Dependency(\.defaultDatabase) var database

    private init() {}

    private func withReadDB<T>(_ db: Database?, _ body: (Database) throws -> T) throws -> T {
        if let db { return try body(db) }
        return try self.database.read(body)
    }

    // MARK: - StoredTracklist

    func maxTracklistSortOrder(type: String, db: Database? = nil) throws -> String? {
        try self.withReadDB(db) { db in
            try StoredTracklist
                .where { $0.tracklistType.eq(type) }
                .order { $0.sortOrder.desc() }
                .fetchOne(db)?
                .sortOrder
        }
    }

    func tracklistSortOrders(
        for storedTracklists: [StoredTracklist?],
        db: Database? = nil
    ) throws -> [String?] {
        let mediaIds = storedTracklists.compactMap { $0?.mediaId }
        guard !mediaIds.isEmpty else { return storedTracklists.map { _ in nil } }

        return try self.withReadDB(db) { db in
            let sortOrderByKey = try Dictionary(
                StoredTracklist
                    .where { $0.mediaId.in(mediaIds) }
                    .fetchAll(db)
                    .map { (Self.key($0.mediaId, $0.mediaSourceId), $0.sortOrder) },
                uniquingKeysWith: { first, _ in first }
            )
            return storedTracklists.map { stored in
                guard let stored else { return nil }
                return sortOrderByKey[Self.key(stored.mediaId, stored.mediaSourceId)]
            }
        }
    }

    // MARK: - StoredTracklistTrack

    func maxTrackSortOrder(
        tracklist: StoredTracklist,
        db: Database? = nil
    ) throws -> String? {
        try self.withReadDB(db) { db in
            try StoredTracklistTrack
                .where {
                    $0.tracklistMediaId.eq(tracklist.mediaId)
                        .and($0.tracklistMediaSourceId.eq(tracklist.mediaSourceId))
                }
                .order { $0.sortOrder.desc() }
                .fetchOne(db)?
                .sortOrder
        }
    }

    func trackSortOrder(
        tracklist: StoredTracklist,
        track: StoredTrack,
        db: Database? = nil
    ) throws -> String? {
        try self.withReadDB(db) { db in
            try StoredTracklistTrack
                .where {
                    $0.tracklistMediaId.eq(tracklist.mediaId)
                        .and($0.tracklistMediaSourceId.eq(tracklist.mediaSourceId))
                        .and($0.trackMediaId.eq(track.mediaId))
                        .and($0.trackMediaSourceId.eq(track.mediaSourceId))
                }
                .fetchOne(db)?
                .sortOrder
        }
    }

    private static func key(_ mediaId: String, _ mediaSourceId: String) -> String {
        "\(mediaId)|\(mediaSourceId)"
    }
}
