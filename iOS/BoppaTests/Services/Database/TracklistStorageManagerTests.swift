@testable import Boppa
import Dependencies
internal import Foundation
import SQLiteData
import Testing

struct TracklistStorageManagerTests {
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

        func read<R>(_ operation: (Database) throws -> R) throws -> R {
            try self.db.read(operation)
        }

        func track(_ mediaId: String, _ source: String = "src") throws -> StoredTrack? {
            try self.db.read { db in
                try StoredTrack.where { $0.mediaId.eq(mediaId).and($0.mediaSourceId.eq(source)) }
                    .fetchOne(db)
            }
        }
    }

    // MARK: - Fixtures

    private func makeTrack(
        _ mediaId: String,
        source: String = "src",
        title: String = "Track Title",
        subtitle: String? = nil,
        duration: Int? = nil,
        lowResArtworkUrl: String? = nil,
        highResArtworkUrl: String? = nil,
        url: String? = nil,
        artists: [Artist] = [],
        albums: [Tracklist] = []
    ) -> Track {
        Track(
            mediaId: mediaId,
            mediaSourceId: source,
            title: title,
            subtitle: subtitle,
            duration: duration,
            lowResArtworkUrl: lowResArtworkUrl,
            highResArtworkUrl: highResArtworkUrl,
            url: url,
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
            mediaId: mediaId, mediaSourceId: source, title: title, url: url, tracklistType: type
        )
    }

    // MARK: - loadAlbums

    @Test func loadAlbumsForSingleElementArrayWithNoAlbumsReturnsEmpty() throws {
        let ctx = try Context()
        try ctx.write { db in
            try TrackStorageManager.shared.upsertTrack(self.makeTrack("t1"), db: db)
        }

        let albumsByTrack = try ctx.withDatabase {
            TracklistStorageManager.shared.loadAlbums(
                forTrackMediaIds: ["t1"], mediaSourceId: "src"
            )
        }

        #expect(albumsByTrack["t1"] == nil)
    }

    @Test func loadAlbumsGroupsResultsByTrackAndPreservesPerTrackOrder() throws {
        let ctx = try Context()
        try ctx.write { db in
            try TrackStorageManager.shared.upsertTrack(
                self.makeTrack(
                    "t1",
                    albums: [self.makeAlbum("al1", title: "First"), self.makeAlbum(
                        "al2",
                        title: "Second"
                    )]
                ), db: db
            )
            try TrackStorageManager.shared.upsertTrack(
                self.makeTrack("t2", albums: [self.makeAlbum("al3", title: "Album Two")]), db: db
            )
            try TrackStorageManager.shared.upsertTrack(self.makeTrack("t3"), db: db)
        }

        let albumsByTrack = try ctx.withDatabase {
            TracklistStorageManager.shared.loadAlbums(
                forTrackMediaIds: ["t1", "t2", "t3"], mediaSourceId: "src"
            )
        }

        #expect(albumsByTrack["t1"]?.map(\.title) == ["First", "Second"])
        #expect(albumsByTrack["t2"]?.map(\.title) == ["Album Two"])
        #expect(albumsByTrack["t3"] == nil)
    }

    @Test func loadAlbumsScopesToMediaSource() throws {
        let ctx = try Context()
        try ctx.write { db in
            try TrackStorageManager.shared.upsertTrack(
                self.makeTrack("t1", source: "src", albums: [self.makeAlbum("al1", source: "src")]),
                db: db
            )
            try TrackStorageManager.shared.upsertTrack(
                self.makeTrack(
                    "t1", source: "other", albums: [self.makeAlbum("al1", source: "other")]
                ),
                db: db
            )
        }

        let albumsByTrack = try ctx.withDatabase {
            TracklistStorageManager.shared.loadAlbums(
                forTrackMediaIds: ["t1"], mediaSourceId: "src"
            )
        }

        #expect(albumsByTrack["t1"]?.count == 1)
    }

    @Test func loadAlbumsReturnsEmptyForEmptyInput() throws {
        let ctx = try Context()
        let albumsByTrack = try ctx.withDatabase {
            TracklistStorageManager.shared.loadAlbums(forTrackMediaIds: [], mediaSourceId: "src")
        }
        #expect(albumsByTrack.isEmpty)
    }
}
