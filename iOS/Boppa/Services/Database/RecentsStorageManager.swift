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
            let artists = try StoredRecentlyViewedArtist
                .where { $0.mediaSourceId.eq(mediaSourceId) }
                .fetchAll(db)
                .map { RecentlyViewedItem.artist($0.toArtist(), viewedAt: $0.viewedAt) }

            let tracklists = try StoredRecentlyViewedTracklist
                .where { $0.mediaSourceId.eq(mediaSourceId) }
                .fetchAll(db)
                .map { RecentlyViewedItem.tracklist($0.toTracklist(), viewedAt: $0.viewedAt) }

            return Array((artists + tracklists).sorted { $0.viewedAt > $1.viewedAt }.prefix(limit))
        }) ?? []
    }

    func fetchRecentlyPlayed(mediaSourceId: String, limit: Int = 10) -> [Track] {
        (try? self.database.read { db in
            try StoredRecentlyPlayedTrack
                .where { $0.mediaSourceId.eq(mediaSourceId) }
                .order { $0.playedAt.desc() }
                .limit(limit)
                .fetchAll(db)
                .map { $0.toTrack() }
        }) ?? []
    }

    // MARK: - Writes

    func recordViewedArtist(_ artist: Artist) {
        let now = Date().timeIntervalSince1970
        try? self.database.write { db in
            try StoredRecentlyViewedArtist.insert {
                StoredRecentlyViewedArtist.Draft(
                    mediaId: artist.mediaId,
                    mediaSourceId: artist.mediaSourceId,
                    name: artist.name,
                    artworkUrl: artist.artworkUrl,
                    viewedAt: now
                )
            } onConflictDoUpdate: {
                $0.name = artist.name
                $0.artworkUrl = artist.artworkUrl
                $0.viewedAt = now
            }
            .execute(db)

            try Self.trimOverflow(StoredRecentlyViewedArtist.self, mediaSourceId: artist.mediaSourceId, db: db)
        }
        logger.info("Recorded viewed artist '\(artist.mediaId)' for source '\(artist.mediaSourceId)'")
        NotificationCenter.default.post(name: .recentlyViewedChanged, object: nil)
    }

    func recordViewedTracklist(_ tracklist: Tracklist) {
        let now = Date().timeIntervalSince1970
        try? self.database.write { db in
            try StoredRecentlyViewedTracklist.insert {
                StoredRecentlyViewedTracklist.Draft(
                    mediaId: tracklist.mediaId,
                    mediaSourceId: tracklist.mediaSourceId,
                    title: tracklist.title,
                    subtitle: tracklist.subtitle,
                    artworkUrl: tracklist.artworkUrl,
                    tracklistType: tracklist.tracklistType.rawValue,
                    viewedAt: now
                )
            } onConflictDoUpdate: {
                $0.title = tracklist.title
                $0.subtitle = tracklist.subtitle
                $0.artworkUrl = tracklist.artworkUrl
                $0.tracklistType = tracklist.tracklistType.rawValue
                $0.viewedAt = now
            }
            .execute(db)

            try Self.trimOverflow(StoredRecentlyViewedTracklist.self, mediaSourceId: tracklist.mediaSourceId, db: db)
        }
        logger.info("Recorded viewed tracklist '\(tracklist.mediaId)' for source '\(tracklist.mediaSourceId)'")
        NotificationCenter.default.post(name: .recentlyViewedChanged, object: nil)
    }

    func recordPlayedTrack(_ track: Track, notify: Bool = true) {
        let now = Date().timeIntervalSince1970
        try? self.database.write { db in
            try StoredRecentlyPlayedTrack.insert {
                StoredRecentlyPlayedTrack.Draft(
                    mediaId: track.mediaId,
                    mediaSourceId: track.mediaSourceId,
                    title: track.title,
                    subtitle: track.subtitle,
                    duration: track.duration,
                    artworkUrl: track.artworkUrl,
                    url: track.url,
                    playedAt: now
                )
            } onConflictDoUpdate: {
                $0.title = track.title
                $0.subtitle = track.subtitle
                $0.duration = track.duration
                $0.artworkUrl = track.artworkUrl
                $0.url = track.url
                $0.playedAt = now
            }
            .execute(db)

            try Self.trimOverflow(StoredRecentlyPlayedTrack.self, mediaSourceId: track.mediaSourceId, db: db)
        }
        logger.info("Recorded played track '\(track.mediaId)' for source '\(track.mediaSourceId)'")
        guard notify else { return }
        NotificationCenter.default.post(name: .recentlyPlayedChanged, object: nil)
    }

    func clearRecentlyViewed(mediaSourceId: String) {
        try? self.database.write { db in
            try StoredRecentlyViewedArtist.where { $0.mediaSourceId.eq(mediaSourceId) }.delete().execute(db)
            try StoredRecentlyViewedTracklist.where { $0.mediaSourceId.eq(mediaSourceId) }.delete().execute(db)
        }
        logger.info("Cleared recently viewed for source '\(mediaSourceId)'")
        NotificationCenter.default.post(name: .recentlyViewedChanged, object: nil)
    }

    func clearRecentlyPlayed(mediaSourceId: String) {
        try? self.database.write { db in
            try StoredRecentlyPlayedTrack.where { $0.mediaSourceId.eq(mediaSourceId) }.delete().execute(db)
        }
        logger.info("Cleared recently played for source '\(mediaSourceId)'")
        NotificationCenter.default.post(name: .recentlyPlayedChanged, object: nil)
    }

    // MARK: - Private

    private static func trimOverflow(
        _: StoredRecentlyViewedArtist.Type,
        mediaSourceId: String,
        db: Database
    ) throws {
        let all = try StoredRecentlyViewedArtist
            .where { $0.mediaSourceId.eq(mediaSourceId) }
            .order { $0.viewedAt.desc() }
            .fetchAll(db)
        guard all.count > Self.maxItemsPerSource else { return }
        let overflowIds = all[Self.maxItemsPerSource...].map(\.mediaId)
        try StoredRecentlyViewedArtist
            .where { $0.mediaSourceId.eq(mediaSourceId).and($0.mediaId.in(overflowIds)) }
            .delete()
            .execute(db)
    }

    private static func trimOverflow(
        _: StoredRecentlyViewedTracklist.Type,
        mediaSourceId: String,
        db: Database
    ) throws {
        let all = try StoredRecentlyViewedTracklist
            .where { $0.mediaSourceId.eq(mediaSourceId) }
            .order { $0.viewedAt.desc() }
            .fetchAll(db)
        guard all.count > Self.maxItemsPerSource else { return }
        let overflowIds = all[Self.maxItemsPerSource...].map(\.mediaId)
        try StoredRecentlyViewedTracklist
            .where { $0.mediaSourceId.eq(mediaSourceId).and($0.mediaId.in(overflowIds)) }
            .delete()
            .execute(db)
    }

    private static func trimOverflow(
        _: StoredRecentlyPlayedTrack.Type,
        mediaSourceId: String,
        db: Database
    ) throws {
        let all = try StoredRecentlyPlayedTrack
            .where { $0.mediaSourceId.eq(mediaSourceId) }
            .order { $0.playedAt.desc() }
            .fetchAll(db)
        guard all.count > Self.maxItemsPerSource else { return }
        let overflowIds = all[Self.maxItemsPerSource...].map(\.mediaId)
        try StoredRecentlyPlayedTrack
            .where { $0.mediaSourceId.eq(mediaSourceId).and($0.mediaId.in(overflowIds)) }
            .delete()
            .execute(db)
    }
}
