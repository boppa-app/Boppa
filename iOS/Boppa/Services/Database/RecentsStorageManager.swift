import Dependencies
import Foundation
import os
import SQLiteData

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Boppa", category: "RecentsStorageManager")

extension Notification.Name {
    static let recentlyPlayedChanged = Notification.Name("recentlyPlayedChanged")
    static let recentlyViewedChanged = Notification.Name("recentlyViewedChanged")
}

class RecentsStorageManager {
    static let shared = RecentsStorageManager()

    @Dependency(\.defaultDatabase) var database

    private static let maxItemsPerSource = 25

    private init() {}

    // MARK: - Reads

    func fetchRecentlyViewed(mediaSourceId: String, limit: Int = 10) -> [RecentlyViewedItem] {
        (try? self.database.read { db -> [RecentlyViewedItem] in
            let artists = try StoredArtist
                .where { $0.mediaSourceId.eq(mediaSourceId).and($0.isRecent.eq(true)) }
                .fetchAll(db)
                .map { RecentlyViewedItem.artist($0.toArtist(), viewedAt: $0.lastViewedTimestamp ?? 0) }

            let tracklists = try StoredTracklist
                .where { $0.mediaSourceId.eq(mediaSourceId).and($0.isRecent.eq(true)) }
                .fetchAll(db)
                .map { RecentlyViewedItem.tracklist(Tracklist(storedTracklist: $0), viewedAt: $0.lastViewedTimestamp ?? 0) }

            return Array((artists + tracklists).sorted { $0.viewedAt > $1.viewedAt }.prefix(limit))
        }) ?? []
    }

    func fetchRecentlyPlayed(mediaSourceId: String, limit: Int = 10) -> [Track] {
        (try? self.database.read { db in
            try StoredTrack
                .where { $0.mediaSourceId.eq(mediaSourceId).and($0.isRecent.eq(true)) }
                .order { $0.lastPlayedTimestamp.desc() }
                .limit(limit)
                .fetchAll(db)
                .map { stored in
                    let artists = try TrackStorageManager.shared.loadArtistsForTrack(stored, db: db)
                    let albums = try TrackStorageManager.shared.loadAlbumsForTrack(stored, db: db)
                    return stored.toTrack(artists: artists, albums: albums)
                }
        }) ?? []
    }

    // MARK: - Writes

    func recordViewedArtist(_ artist: Artist) {
        let now = Date().timeIntervalSince1970
        try? self.database.write { db in
            try TrackStorageManager.shared.markArtistRecentlyViewed(artist, viewedAt: now, db: db)
            try Self.trimOverflowArtists(mediaSourceId: artist.mediaSourceId, db: db)
        }
        logger.info("Recorded viewed artist '\(artist.mediaId)' for source '\(artist.mediaSourceId)'")
        NotificationCenter.default.post(name: .recentlyViewedChanged, object: nil)
    }

    func recordViewedTracklist(_ tracklist: Tracklist) {
        let now = Date().timeIntervalSince1970
        try? self.database.write { db in
            try TracklistStorageManager.shared.markTracklistRecentlyViewed(tracklist, viewedAt: now, db: db)
            try Self.trimOverflowTracklists(mediaSourceId: tracklist.mediaSourceId, db: db)
        }
        logger.info("Recorded viewed tracklist '\(tracklist.mediaId)' for source '\(tracklist.mediaSourceId)'")
        NotificationCenter.default.post(name: .recentlyViewedChanged, object: nil)
    }

    func recordPlayedTrack(_ track: Track, notify: Bool = true) {
        let now = Date().timeIntervalSince1970
        try? self.database.write { db in
            try TrackStorageManager.shared.markRecentlyPlayed(track, playedAt: now, db: db)
            try Self.trimOverflowTracks(mediaSourceId: track.mediaSourceId, db: db)
        }
        logger.info("Recorded played track '\(track.mediaId)' for source '\(track.mediaSourceId)'")
        guard notify else { return }
        NotificationCenter.default.post(name: .recentlyPlayedChanged, object: nil)
    }

    func removeRecentlyViewedArtist(mediaId: String, mediaSourceId: String) {
        try? self.database.write { db in
            try TrackStorageManager.shared.unmarkArtistRecentlyViewed(mediaId: mediaId, mediaSourceId: mediaSourceId, db: db)
        }
        logger.info("Removed recently viewed artist '\(mediaId)' for source '\(mediaSourceId)'")
        NotificationCenter.default.post(name: .recentlyViewedChanged, object: nil)
    }

    func removeRecentlyViewedTracklist(mediaId: String, mediaSourceId: String) {
        try? self.database.write { db in
            try TrackStorageManager.shared.unmarkTracklistRecentlyViewed(mediaId: mediaId, mediaSourceId: mediaSourceId, db: db)
        }
        logger.info("Removed recently viewed tracklist '\(mediaId)' for source '\(mediaSourceId)'")
        NotificationCenter.default.post(name: .recentlyViewedChanged, object: nil)
    }

    func removeRecentlyPlayed(mediaIds: [String], mediaSourceId: String) {
        guard !mediaIds.isEmpty else { return }
        try? self.database.write { db in
            for mediaId in mediaIds {
                try TrackStorageManager.shared.unmarkRecentlyPlayed(mediaId: mediaId, mediaSourceId: mediaSourceId, db: db)
            }
        }
        logger.info("Removed \(mediaIds.count) recently played track(s) for source '\(mediaSourceId)'")
        NotificationCenter.default.post(name: .recentlyPlayedChanged, object: nil)
    }

    // MARK: - Private

    private static func trimOverflowArtists(mediaSourceId: String, db: Database) throws {
        let all = try StoredArtist
            .where { $0.mediaSourceId.eq(mediaSourceId).and($0.isRecent.eq(true)) }
            .order { $0.lastViewedTimestamp.desc() }
            .fetchAll(db)
        guard all.count > Self.maxItemsPerSource else { return }
        for artist in all[Self.maxItemsPerSource...] {
            try TrackStorageManager.shared.unmarkArtistRecentlyViewed(mediaId: artist.mediaId, mediaSourceId: artist.mediaSourceId, db: db)
        }
    }

    private static func trimOverflowTracklists(mediaSourceId: String, db: Database) throws {
        let all = try StoredTracklist
            .where { $0.mediaSourceId.eq(mediaSourceId).and($0.isRecent.eq(true)) }
            .order { $0.lastViewedTimestamp.desc() }
            .fetchAll(db)
        guard all.count > Self.maxItemsPerSource else { return }
        for tracklist in all[Self.maxItemsPerSource...] {
            try TrackStorageManager.shared.unmarkTracklistRecentlyViewed(mediaId: tracklist.mediaId, mediaSourceId: tracklist.mediaSourceId, db: db)
        }
    }

    private static func trimOverflowTracks(mediaSourceId: String, db: Database) throws {
        let all = try StoredTrack
            .where { $0.mediaSourceId.eq(mediaSourceId).and($0.isRecent.eq(true)) }
            .order { $0.lastPlayedTimestamp.desc() }
            .fetchAll(db)
        guard all.count > Self.maxItemsPerSource else { return }
        for track in all[Self.maxItemsPerSource...] {
            try TrackStorageManager.shared.unmarkRecentlyPlayed(mediaId: track.mediaId, mediaSourceId: track.mediaSourceId, db: db)
        }
    }
}
