import Dependencies
import Foundation
import os
import SQLiteData

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "Boppa",
    category: "RecentsStorageManager"
)

extension Notification.Name {
    static let recentlyPlayedChanged = Notification.Name("recentlyPlayedChanged")
    static let recentlyViewedChanged = Notification.Name("recentlyViewedChanged")
}

class RecentsStorageManager {
    static let shared = RecentsStorageManager()

    @Dependency(\.defaultDatabase) var database

    private static let maxItemsPerSource = 100

    private init() {}

    // MARK: - DB Access

    private func withReadDB<T>(_ db: Database?, _ body: (Database) throws -> T) throws -> T {
        if let db { return try body(db) }
        return try self.database.read(body)
    }

    private func withWriteDB<T>(_ db: Database?, _ body: (Database) throws -> T) throws -> T {
        if let db { return try body(db) }
        return try self.database.write(body)
    }

    // MARK: - Reads

    func fetchRecentlyViewed(
        mediaSourceId: String,
        limit: Int = 10,
        db: Database? = nil
    ) -> [RecentlyViewedItem] {
        (try? self.withReadDB(db) { db -> [RecentlyViewedItem] in
            let artists = try StoredArtist
                .where { $0.mediaSourceId.eq(mediaSourceId).and($0.isRecent.eq(true)) }
                .fetchAll(db)
                .map { RecentlyViewedItem.artist(
                    $0.toArtist(),
                    viewedAt: $0.lastViewedTimestamp ?? 0
                ) }

            let tracklists = try StoredTracklist
                .where { $0.mediaSourceId.eq(mediaSourceId).and($0.isRecent.eq(true)) }
                .fetchAll(db)
                .map { RecentlyViewedItem.tracklist(
                    Tracklist(storedTracklist: $0),
                    viewedAt: $0.lastViewedTimestamp ?? 0
                ) }

            return Array((artists + tracklists).sorted { $0.viewedAt > $1.viewedAt }.prefix(limit))
        }) ?? []
    }

    func fetchRecentlyPlayed(
        mediaSourceId: String,
        limit: Int = 10,
        db: Database? = nil
    ) -> [Track] {
        let storedTracks: [StoredTrack] = (try? self.withReadDB(db) { db in
            try StoredTrack
                .where { $0.mediaSourceId.eq(mediaSourceId).and($0.isRecent.eq(true)) }
                .order { $0.lastPlayedTimestamp.desc() }
                .limit(limit)
                .fetchAll(db)
        }) ?? []
        let albumPairs = (try? TracklistStorageManager.shared.fetchStoredAlbumsForTracks(
            storedTracks.map { $0.toTrack() },
            db: db
        )) ?? []
        var albumsByTrackMediaId: [String: [Tracklist]] = [:]
        for (track, album) in albumPairs {
            albumsByTrackMediaId[track.mediaId, default: []]
                .append(Tracklist(storedTracklist: album))
        }
        return storedTracks.map { stored in
            stored.toTrack(albums: albumsByTrackMediaId[stored.mediaId] ?? [])
        }
    }

    // MARK: - Writes

    func markArtistRecentlyViewed(
        _ artist: Artist,
        viewedAt: Double,
        db: Database? = nil
    ) throws {
        try self.withWriteDB(db) { db in
            try ArtistStorageManager.shared.upsertArtists([artist], db: db)
            try StoredArtist.update {
                $0.isRecent = true
                $0.lastViewedTimestamp = #bind(viewedAt)
            }
            .where { $0.mediaId.eq(artist.mediaId).and($0.mediaSourceId.eq(artist.mediaSourceId)) }
            .execute(db)
        }
    }

    func unmarkArtistRecentlyViewed(_ artist: Artist, db: Database? = nil) throws {
        try self.withWriteDB(db) { db in
            try StoredArtist.update { $0.isRecent = false }
                .where {
                    $0.mediaId.eq(artist.mediaId).and($0.mediaSourceId.eq(artist.mediaSourceId))
                }
                .execute(db)
            try ArtistStorageManager.shared.deleteArtistStubsIfOrphaned([artist], db: db)
        }
    }

    func markTracklistRecentlyViewed(
        _ tracklist: Tracklist,
        viewedAt: Double,
        db: Database? = nil
    ) throws {
        try self.withWriteDB(db) { db in
            try TracklistStorageManager.shared.upsertTracklistStubs([tracklist], db: db)
            try StoredTracklist.update {
                $0.isRecent = true
                $0.lastViewedTimestamp = #bind(viewedAt)
            }
            .where {
                $0.mediaId.eq(tracklist.mediaId).and($0.mediaSourceId.eq(tracklist.mediaSourceId))
            }
            .execute(db)
        }
    }

    func unmarkTracklistRecentlyViewed(_ tracklist: Tracklist, db: Database? = nil) throws {
        try self.withWriteDB(db) { db in
            try StoredTracklist.update { $0.isRecent = false }
                .where {
                    $0.mediaId.eq(tracklist.mediaId)
                        .and($0.mediaSourceId.eq(tracklist.mediaSourceId))
                }
                .execute(db)
            try TracklistStorageManager.shared.deleteAlbumStubsIfOrphaned([tracklist], db: db)
        }
    }

    func markTrackRecentlyPlayed(_ track: Track, playedAt: Double, db: Database? = nil) throws {
        try self.withWriteDB(db) { db in
            let existing =
                try StoredTrack
                    .where {
                        $0.mediaId.eq(track.mediaId).and($0.mediaSourceId.eq(track.mediaSourceId))
                    }
                    .fetchOne(db)
            if existing == nil {
                try TrackStorageManager.shared.upsertTracks([track], db: db)
            }
            try StoredTrack.update {
                $0.isRecent = true
                $0.lastPlayedTimestamp = #bind(playedAt)
            }
            .where { $0.mediaId.eq(track.mediaId).and($0.mediaSourceId.eq(track.mediaSourceId)) }
            .execute(db)
        }
    }

    func unmarkTrackRecentlyPlayedTrack(_ track: Track, db: Database? = nil) throws {
        try self.withWriteDB(db) { db in
            try StoredTrack.update { $0.isRecent = false }
                .where { $0.mediaId.eq(track.mediaId).and($0.mediaSourceId.eq(track.mediaSourceId))
                }
                .execute(db)
            try TrackStorageManager.shared.deleteTrackStubsIfOrphaned([track], db: db)
        }
    }

    func recordViewedArtist(_ artist: Artist, db: Database? = nil) {
        let now = Date().timeIntervalSince1970
        try? self.withWriteDB(db) { db in
            try self.markArtistRecentlyViewed(artist, viewedAt: now, db: db)
            try Self.trimOverflowArtists(mediaSourceId: artist.mediaSourceId, db: db)
        }
        logger
            .info("Recorded viewed artist '\(artist.mediaId)' for source '\(artist.mediaSourceId)'")
        NotificationCenter.default.post(name: .recentlyViewedChanged, object: nil)
    }

    func recordViewedTracklist(_ tracklist: Tracklist, db: Database? = nil) {
        let now = Date().timeIntervalSince1970
        try? self.withWriteDB(db) { db in
            try self.markTracklistRecentlyViewed(tracklist, viewedAt: now, db: db)
            try Self.trimOverflowTracklists(mediaSourceId: tracklist.mediaSourceId, db: db)
        }
        logger
            .info(
                "Recorded viewed tracklist '\(tracklist.mediaId)' for source '\(tracklist.mediaSourceId)'"
            )
        NotificationCenter.default.post(name: .recentlyViewedChanged, object: nil)
    }

    func recordPlayedTrack(_ track: Track, notify: Bool = true, db: Database? = nil) {
        let now = Date().timeIntervalSince1970
        try? self.withWriteDB(db) { db in
            try self.markTrackRecentlyPlayed(track, playedAt: now, db: db)
            try Self.trimOverflowTracks(mediaSourceId: track.mediaSourceId, db: db)
        }
        logger.info("Recorded played track '\(track.mediaId)' for source '\(track.mediaSourceId)'")
        guard notify else { return }
        NotificationCenter.default.post(name: .recentlyPlayedChanged, object: nil)
    }

    func removeRecentlyViewedArtist(_ artist: Artist, db: Database? = nil) {
        try? self.withWriteDB(db) { db in
            try self.unmarkArtistRecentlyViewed(artist, db: db)
        }
        logger
            .info(
                "Removed recently viewed artist '\(artist.mediaId)' for source '\(artist.mediaSourceId)'"
            )
    }

    func removeRecentlyViewedTracklist(_ tracklist: Tracklist, db: Database? = nil) {
        try? self.withWriteDB(db) { db in
            try self.unmarkTracklistRecentlyViewed(tracklist, db: db)
        }
        logger
            .info(
                "Removed recently viewed tracklist '\(tracklist.mediaId)' for source '\(tracklist.mediaSourceId)'"
            )
        NotificationCenter.default.post(name: .recentlyViewedChanged, object: nil)
    }

    func removeRecentlyPlayedTrack(_ track: Track, db: Database? = nil) {
        try? self.withWriteDB(db) { db in
            try self.unmarkTrackRecentlyPlayedTrack(track, db: db)
        }
        logger.info("Removed recently played track '\(track.mediaId)'")
    }

    private static func trimOverflowArtists(mediaSourceId: String, db: Database) throws {
        let all = try StoredArtist
            .where { $0.mediaSourceId.eq(mediaSourceId).and($0.isRecent.eq(true)) }
            .order { $0.lastViewedTimestamp.desc() }
            .fetchAll(db)
        guard all.count > Self.maxItemsPerSource else { return }
        let overflow = Array(all[Self.maxItemsPerSource...])
        try StoredArtist.update { $0.isRecent = false }
            .where { $0.mediaSourceId.eq(mediaSourceId).and($0.mediaId.in(overflow.map(\.mediaId)))
            }
            .execute(db)
        try ArtistStorageManager.shared.deleteArtistStubsIfOrphaned(
            overflow.map { $0.toArtist() },
            db: db
        )
    }

    private static func trimOverflowTracklists(mediaSourceId: String, db: Database) throws {
        let all = try StoredTracklist
            .where { $0.mediaSourceId.eq(mediaSourceId).and($0.isRecent.eq(true)) }
            .order { $0.lastViewedTimestamp.desc() }
            .fetchAll(db)
        guard all.count > Self.maxItemsPerSource else { return }
        let overflow = Array(all[Self.maxItemsPerSource...])
        try StoredTracklist.update { $0.isRecent = false }
            .where { $0.mediaSourceId.eq(mediaSourceId).and($0.mediaId.in(overflow.map(\.mediaId)))
            }
            .execute(db)
        try TracklistStorageManager.shared.deleteAlbumStubsIfOrphaned(
            overflow.map { Tracklist(storedTracklist: $0) },
            db: db
        )
    }

    private static func trimOverflowTracks(mediaSourceId: String, db: Database) throws {
        let all = try StoredTrack
            .where { $0.mediaSourceId.eq(mediaSourceId).and($0.isRecent.eq(true)) }
            .order { $0.lastPlayedTimestamp.desc() }
            .fetchAll(db)
        guard all.count > Self.maxItemsPerSource else { return }
        let overflow = Array(all[Self.maxItemsPerSource...])
        try StoredTrack.update { $0.isRecent = false }
            .where { $0.mediaSourceId.eq(mediaSourceId).and($0.mediaId.in(overflow.map(\.mediaId)))
            }
            .execute(db)
        try TrackStorageManager.shared.deleteTrackStubsIfOrphaned(
            overflow.map { $0.toTrack() },
            db: db
        )
    }
}
