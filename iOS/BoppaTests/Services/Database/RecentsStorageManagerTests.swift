@testable import Boppa
import Dependencies
internal import Foundation
import SQLiteData
import Testing

struct RecentsStorageManagerTests {
    // MARK: - Test Infrastructure

    private struct Context {
        let db: DatabaseQueue

        init() throws {
            var configuration = Configuration()
            configuration.foreignKeysEnabled = true
            let database = try DatabaseQueue(configuration: configuration)
            var migrator = DatabaseMigrator()
            migrator.registerMigration("v1") { db in
                try #sql(
                    """
                    CREATE TABLE "artists" (
                      "mediaId" TEXT NOT NULL,
                      "mediaSourceId" TEXT NOT NULL,
                      "name" TEXT NOT NULL,
                      "lowResArtworkUrl" TEXT,
                      "highResArtworkUrl" TEXT,
                      "url" TEXT,
                      "isSavedToLibrary" INTEGER NOT NULL DEFAULT 0,
                      "lastViewedTimestamp" REAL,
                      "isRecent" INTEGER NOT NULL DEFAULT 0,
                      PRIMARY KEY ("mediaId", "mediaSourceId")
                    ) STRICT
                    """
                ).execute(db)

                try #sql(
                    """
                    CREATE TABLE "tracklists" (
                      "mediaId" TEXT NOT NULL,
                      "mediaSourceId" TEXT NOT NULL,
                      "title" TEXT NOT NULL,
                      "subtitle" TEXT,
                      "lowResArtworkUrl" TEXT,
                      "highResArtworkUrl" TEXT,
                      "url" TEXT,
                      "tracklistType" TEXT NOT NULL CHECK (tracklistType IN ('album', 'playlist', 'likes')),
                      "isPinned" INTEGER NOT NULL DEFAULT 0,
                      "isSavedToLibrary" INTEGER NOT NULL DEFAULT 0,
                      "year" INTEGER,
                      "sortOrder" TEXT NOT NULL DEFAULT 'a0',
                      "lastViewedTimestamp" REAL,
                      "isRecent" INTEGER NOT NULL DEFAULT 0,
                      PRIMARY KEY ("mediaId", "mediaSourceId")
                    ) STRICT
                    """
                ).execute(db)

                try #sql(
                    """
                    CREATE TABLE "tracks" (
                      "mediaId" TEXT NOT NULL,
                      "mediaSourceId" TEXT NOT NULL,
                      "title" TEXT NOT NULL,
                      "subtitle" TEXT,
                      "duration" INTEGER,
                      "lowResArtworkUrl" TEXT,
                      "highResArtworkUrl" TEXT,
                      "url" TEXT,
                      "type" TEXT NOT NULL CHECK (type IN ('song', 'video')),
                      "isSavedToLibrary" INTEGER NOT NULL DEFAULT 0,
                      "lastPlayedTimestamp" REAL,
                      "isRecent" INTEGER NOT NULL DEFAULT 0,
                      "metadata" BLOB,
                      PRIMARY KEY ("mediaId", "mediaSourceId")
                    ) STRICT
                    """
                ).execute(db)

                try #sql(
                    """
                    CREATE TABLE "tracklistTracks" (
                      "tracklistMediaId" TEXT NOT NULL,
                      "tracklistMediaSourceId" TEXT NOT NULL,
                      "trackMediaId" TEXT NOT NULL,
                      "trackMediaSourceId" TEXT NOT NULL,
                      "sortOrder" TEXT NOT NULL DEFAULT 'a0',
                      PRIMARY KEY ("tracklistMediaId", "tracklistMediaSourceId", "trackMediaId", "trackMediaSourceId"),
                      FOREIGN KEY ("tracklistMediaId", "tracklistMediaSourceId") REFERENCES "tracklists"("mediaId", "mediaSourceId") ON DELETE CASCADE,
                      FOREIGN KEY ("trackMediaId", "trackMediaSourceId") REFERENCES "tracks"("mediaId", "mediaSourceId")
                    ) STRICT
                    """
                ).execute(db)

                try #sql(
                    """
                    CREATE TABLE "trackArtists" (
                      "trackMediaId" TEXT NOT NULL,
                      "trackMediaSourceId" TEXT NOT NULL,
                      "artistMediaId" TEXT NOT NULL,
                      "artistMediaSourceId" TEXT NOT NULL,
                      "sortOrder" TEXT NOT NULL DEFAULT 'a0',
                      PRIMARY KEY ("trackMediaId", "trackMediaSourceId", "artistMediaId", "artistMediaSourceId"),
                      FOREIGN KEY ("trackMediaId", "trackMediaSourceId") REFERENCES "tracks"("mediaId", "mediaSourceId") ON DELETE CASCADE,
                      FOREIGN KEY ("artistMediaId", "artistMediaSourceId") REFERENCES "artists"("mediaId", "mediaSourceId")
                    ) STRICT
                    """
                ).execute(db)

                try #sql(
                    """
                    CREATE TABLE "trackAlbums" (
                      "trackMediaId" TEXT NOT NULL,
                      "trackMediaSourceId" TEXT NOT NULL,
                      "tracklistMediaId" TEXT NOT NULL,
                      "tracklistMediaSourceId" TEXT NOT NULL,
                      "sortOrder" TEXT NOT NULL DEFAULT 'a0',
                      PRIMARY KEY ("trackMediaId", "trackMediaSourceId", "tracklistMediaId", "tracklistMediaSourceId"),
                      FOREIGN KEY ("trackMediaId", "trackMediaSourceId") REFERENCES "tracks"("mediaId", "mediaSourceId") ON DELETE CASCADE,
                      FOREIGN KEY ("tracklistMediaId", "tracklistMediaSourceId") REFERENCES "tracklists"("mediaId", "mediaSourceId") ON DELETE CASCADE
                    ) STRICT
                    """
                ).execute(db)
            }
            try migrator.migrate(database)
            self.db = database
        }

        func withDatabase<R>(_ operation: () throws -> R) throws -> R {
            try withDependencies {
                $0.defaultDatabase = self.db
            } operation: {
                try operation()
            }
        }

        func write<R>(_ operation: (Database) throws -> R) throws -> R {
            try self.db.write(operation)
        }

        func artist(_ mediaId: String, _ source: String = "src") throws -> StoredArtist? {
            try self.db.read { db in
                try StoredArtist.where { $0.mediaId.eq(mediaId).and($0.mediaSourceId.eq(source)) }
                    .fetchOne(db)
            }
        }

        func track(_ mediaId: String, _ source: String = "src") throws -> StoredTrack? {
            try self.db.read { db in
                try StoredTrack.where { $0.mediaId.eq(mediaId).and($0.mediaSourceId.eq(source)) }
                    .fetchOne(db)
            }
        }

        func tracklist(_ mediaId: String, _ source: String = "src") throws -> StoredTracklist? {
            try self.db.read { db in
                try StoredTracklist.where {
                    $0.mediaId.eq(mediaId).and($0.mediaSourceId.eq(source))
                }.fetchOne(db)
            }
        }

        func trackArtistRefs(_ mediaId: String, _ source: String = "src") throws
            -> [StoredTrackArtist]
        {
            try self.db.read { db in
                try StoredTrackArtist
                    .where { $0.trackMediaId.eq(mediaId).and($0.trackMediaSourceId.eq(source)) }
                    .order { $0.sortOrder }
                    .fetchAll(db)
            }
        }

        func trackAlbumRefs(_ mediaId: String, _ source: String = "src") throws
            -> [StoredTrackAlbum]
        {
            try self.db.read { db in
                try StoredTrackAlbum
                    .where { $0.trackMediaId.eq(mediaId).and($0.trackMediaSourceId.eq(source)) }
                    .order { $0.sortOrder }
                    .fetchAll(db)
            }
        }
    }

    // MARK: - Fixtures

    private func makeArtist(
        _ mediaId: String,
        source: String = "src",
        name: String = "Artist Name"
    ) -> Artist {
        Artist(mediaId: mediaId, mediaSourceId: source, name: name)
    }

    private func makeTrack(
        _ mediaId: String,
        source: String = "src",
        title: String = "Track Title",
        artists: [Artist] = [],
        albums: [Tracklist] = []
    ) -> Track {
        Track(
            mediaId: mediaId,
            mediaSourceId: source,
            title: title,
            artists: artists,
            albums: albums
        )
    }

    private func makeAlbum(
        _ mediaId: String,
        source: String = "src",
        title: String = "Album Title",
        type: Tracklist.TracklistType = .album,
        url: String? = nil
    ) -> Tracklist {
        Tracklist(
            mediaId: mediaId, mediaSourceId: source, title: title, url: url,
            tracklistType: type
        )
    }

    // MARK: - markArtistRecentlyViewed / unmarkArtistRecentlyViewed

    @Test func markArtistRecentlyViewedInsertsArtistAndSetsFlag() throws {
        let ctx = try Context()
        let a1 = self.makeArtist("a1", name: "Some Artist")

        try ctx.write { db in
            try RecentsStorageManager.shared.markArtistRecentlyViewed(a1, viewedAt: 55, db: db)
        }

        let stored = try #require(try ctx.artist("a1"))
        #expect(stored.isRecent == true)
        #expect(stored.lastViewedTimestamp == 55)
    }

    @Test func markArtistRecentlyViewedUpdatesTimestampOnRevisit() throws {
        let ctx = try Context()
        let a1 = self.makeArtist("a1")
        try ctx.write { db in
            try RecentsStorageManager.shared.markArtistRecentlyViewed(a1, viewedAt: 100, db: db)
        }

        try ctx.write { db in
            try RecentsStorageManager.shared.markArtistRecentlyViewed(a1, viewedAt: 200, db: db)
        }

        let stored = try #require(try ctx.artist("a1"))
        #expect(stored.lastViewedTimestamp == 200)
    }

    @Test func unmarkArtistRecentlyViewedDeletesOrphanedArtist() throws {
        let ctx = try Context()
        let a1 = self.makeArtist("a1")
        try ctx.write { db in
            try RecentsStorageManager.shared.markArtistRecentlyViewed(a1, viewedAt: 1, db: db)
        }

        try ctx.write { db in
            try RecentsStorageManager.shared.unmarkArtistRecentlyViewed(a1, db: db)
        }

        #expect(try ctx.artist("a1") == nil)
    }

    @Test func unmarkArtistRecentlyViewedKeepsArtistReferencedByTrack() throws {
        let ctx = try Context()
        let a1 = self.makeArtist("a1")
        try ctx.write { db in
            try TrackStorageManager.shared.upsertTrack(self.makeTrack("t1", artists: [a1]), db: db)
            try RecentsStorageManager.shared.markArtistRecentlyViewed(a1, viewedAt: 1, db: db)
        }

        try ctx.write { db in
            try RecentsStorageManager.shared.unmarkArtistRecentlyViewed(a1, db: db)
        }

        #expect(try ctx.artist("a1") != nil)
    }

    @Test func unmarkArtistRecentlyViewedKeepsSavedToLibraryArtist() throws {
        let ctx = try Context()
        let a1 = self.makeArtist("a1")
        try ctx.withDatabase { try ArtistStorageManager.shared.saveArtistToLibrary(a1) }
        try ctx.write { db in
            try RecentsStorageManager.shared.markArtistRecentlyViewed(a1, viewedAt: 1, db: db)
        }

        try ctx.write { db in
            try RecentsStorageManager.shared.unmarkArtistRecentlyViewed(a1, db: db)
        }

        let stored = try #require(try ctx.artist("a1"))
        #expect(stored.isRecent == false)
        #expect(stored.isSavedToLibrary == true)
    }

    // MARK: - markTrackRecentlyPlayed / unmarkTrackRecentlyPlayedTrack

    @Test func markTrackRecentlyPlayedInsertsTrackAndSetsFlagAndTimestamp() throws {
        let ctx = try Context()
        let t1 = self.makeTrack("t1")

        try ctx.write { db in
            try RecentsStorageManager.shared.markTrackRecentlyPlayed(t1, playedAt: 123.0, db: db)
        }

        let stored = try #require(try ctx.track("t1"))
        #expect(stored.isRecent == true)
        #expect(stored.lastPlayedTimestamp == 123.0)
    }

    @Test func markTrackRecentlyPlayedUpdatesTimestampOnReplay() throws {
        let ctx = try Context()
        let t1 = self.makeTrack("t1")
        try ctx.write { db in
            try RecentsStorageManager.shared.markTrackRecentlyPlayed(t1, playedAt: 100, db: db)
        }

        try ctx.write { db in
            try RecentsStorageManager.shared.markTrackRecentlyPlayed(t1, playedAt: 200, db: db)
        }

        let stored = try #require(try ctx.track("t1"))
        #expect(stored.lastPlayedTimestamp == 200)
    }

    @Test func markTrackRecentlyPlayedOnExistingTrackDoesNotTouchScalarsOrRelations() throws {
        let ctx = try Context()
        let full = self.makeTrack(
            "t1",
            title: "Real Title",
            artists: [self.makeArtist("a1", name: "Artist One")],
            albums: [self.makeAlbum("al1", title: "Album One")]
        )
        try ctx.write { db in try TrackStorageManager.shared.upsertTrack(full, db: db) }

        let lightweight = self.makeTrack("t1", title: "Stale Title")
        try ctx.write { db in
            try RecentsStorageManager.shared.markTrackRecentlyPlayed(
                lightweight,
                playedAt: 100,
                db: db
            )
        }

        let stored = try #require(try ctx.track("t1"))
        #expect(stored.isRecent == true)
        #expect(stored.lastPlayedTimestamp == 100)
        #expect(stored.title == "Real Title")
        #expect(try ctx.trackArtistRefs("t1").map(\.artistMediaId) == ["a1"])
        #expect(try ctx.trackAlbumRefs("t1").map(\.tracklistMediaId) == ["al1"])
    }

    @Test func markTrackRecentlyPlayedInsertsNewTrackWithProvidedArtistsAndAlbums() throws {
        let ctx = try Context()
        let t1 = self.makeTrack(
            "t1",
            artists: [self.makeArtist("a1", name: "Artist One")],
            albums: [self.makeAlbum("al1", title: "Album One")]
        )

        try ctx.write { db in
            try RecentsStorageManager.shared.markTrackRecentlyPlayed(t1, playedAt: 100, db: db)
        }

        #expect(try ctx.trackArtistRefs("t1").map(\.artistMediaId) == ["a1"])
        #expect(try ctx.trackAlbumRefs("t1").map(\.tracklistMediaId) == ["al1"])
    }

    @Test func unmarkTrackRecentlyPlayedTrackDeletesOrphanedTrack() throws {
        let ctx = try Context()
        let t1 = self.makeTrack("t1")
        try ctx.write { db in
            try RecentsStorageManager.shared.markTrackRecentlyPlayed(t1, playedAt: 100, db: db)
        }

        try ctx.write { db in
            try RecentsStorageManager.shared.unmarkTrackRecentlyPlayedTrack(t1, db: db)
        }

        #expect(try ctx.track("t1") == nil)
    }

    @Test func unmarkTrackRecentlyPlayedTrackKeepsTrackStillInPlaylist() throws {
        let ctx = try Context()
        let t1 = self.makeTrack("t1")
        try ctx.withDatabase { try PlaylistStorageManager.shared.likeTrack(t1) }
        try ctx.write { db in
            try RecentsStorageManager.shared.markTrackRecentlyPlayed(t1, playedAt: 100, db: db)
        }

        try ctx.write { db in
            try RecentsStorageManager.shared.unmarkTrackRecentlyPlayedTrack(t1, db: db)
        }

        let stored = try #require(try ctx.track("t1"))
        #expect(stored.isRecent == false)
    }

    @Test func likedAndRecentTrackSurvivesUnlikeThenDeletedOnUnmarkRecent() throws {
        let ctx = try Context()
        let t1 = self.makeTrack("t1")
        try ctx.withDatabase { try PlaylistStorageManager.shared.likeTrack(t1) }
        try ctx.write { db in
            try RecentsStorageManager.shared.markTrackRecentlyPlayed(t1, playedAt: 100, db: db)
        }

        try ctx.withDatabase { try PlaylistStorageManager.shared.unlikeTrack(t1) }
        #expect(try ctx.track("t1") != nil)
        try ctx.write { db in
            try RecentsStorageManager.shared.unmarkTrackRecentlyPlayedTrack(t1, db: db)
        }

        #expect(try ctx.track("t1") == nil)
    }
}
