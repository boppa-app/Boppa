import Dependencies
import Foundation
import SQLiteData

class TracklistArtworkResolver {
    static let shared = TracklistArtworkResolver()

    @Dependency(\.defaultDatabase) var database

    private init() {}

    private func withReadDB<T>(_ db: Database?, _ body: (Database) throws -> T) throws -> T {
        if let db { return try body(db) }
        return try self.database.read(body)
    }

    private static let composedArtworkTargetCount = 4
    private static let composedArtworkInitialBatchSize = 8
    private static let composedArtworkMaxBatchSize = 64

    func resolveComposedArtwork(
        mediaId: String,
        mediaSourceId: String,
        db: Database? = nil
    ) -> [TrackArtworkURLs] {
        var collected: [TrackArtworkURLs] = []
        var seenKeys = Set<String>()
        var offset = 0
        var batchSize = Self.composedArtworkInitialBatchSize

        while collected.count < Self.composedArtworkTargetCount {
            let batch: [StoredTrack] = (try? self.withReadDB(db) { db in
                try StoredTracklistTrack
                    .where {
                        $0.tracklistMediaId.eq(mediaId)
                            .and($0.tracklistMediaSourceId.eq(mediaSourceId))
                    }
                    .join(StoredTrack.all) { tt, t in
                        tt.trackMediaId.eq(t.mediaId).and(tt.trackMediaSourceId.eq(t.mediaSourceId))
                    }
                    .order { tt, _ in tt.sortOrder }
                    .select { _, t in t }
                    .limit(batchSize, offset: offset)
                    .fetchAll(db)
            }) ?? []

            guard !batch.isEmpty else { break }

            for track in batch {
                guard let key = track.highResArtworkUrl ?? track.lowResArtworkUrl,
                      !key.isEmpty
                else {
                    continue
                }
                guard seenKeys.insert(key).inserted else { continue }
                collected.append(
                    TrackArtworkURLs(
                        lowResUrl: track.lowResArtworkUrl,
                        highResUrl: track.highResArtworkUrl
                    )
                )
                if collected.count >= Self.composedArtworkTargetCount { break }
            }

            offset += batch.count
            if batch.count < batchSize { break }
            batchSize = min(batchSize * 2, Self.composedArtworkMaxBatchSize)
        }

        return collected
    }
}
