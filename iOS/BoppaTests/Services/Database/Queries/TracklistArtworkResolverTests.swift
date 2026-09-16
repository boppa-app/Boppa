@testable import Boppa
import Dependencies
internal import Foundation
import SQLiteData
import Testing

struct TracklistArtworkResolverTests {
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
    }

    // MARK: - Fixtures

    private func makeTrack(
        _ mediaId: String,
        source: String = "src",
        highResArtworkUrl: String? = nil
    ) -> Track {
        Track(
            mediaId: mediaId,
            mediaSourceId: source,
            title: "Track Title",
            highResArtworkUrl: highResArtworkUrl
        )
    }

    // MARK: - resolveComposedArtwork

    @Test func resolveComposedArtworkReturnsEmptyForTracklistWithNoTracks() throws {
        let ctx = try Context()
        let playlist = try ctx
            .withDatabase { try PlaylistStorageManager.shared.createPlaylist(title: "Empty") }

        let artwork = try ctx.withDatabase {
            TracklistArtworkResolver.shared.resolveComposedArtwork(
                mediaId: playlist.mediaId, mediaSourceId: "boppa.app"
            )
        }

        #expect(artwork.isEmpty)
    }

    @Test func resolveComposedArtworkReturnsEmptyWhenNoTracksHaveArtwork() throws {
        let ctx = try Context()
        let playlist = try ctx
            .withDatabase { try PlaylistStorageManager.shared.createPlaylist(title: "Mix") }
        try ctx.withDatabase {
            try PlaylistStorageManager.shared.addTrackToPlaylist(
                self.makeTrack("t1"),
                toPlaylist: playlist.mediaId
            )
            try PlaylistStorageManager.shared.addTrackToPlaylist(
                self.makeTrack("t2"),
                toPlaylist: playlist.mediaId
            )
        }

        let artwork = try ctx.withDatabase {
            TracklistArtworkResolver.shared.resolveComposedArtwork(
                mediaId: playlist.mediaId, mediaSourceId: "boppa.app"
            )
        }

        #expect(artwork.isEmpty)
    }

    @Test func resolveComposedArtworkCollectsUpToFourDistinctURLsInTrackOrder() throws {
        let ctx = try Context()
        let playlist = try ctx
            .withDatabase { try PlaylistStorageManager.shared.createPlaylist(title: "Mix") }
        try ctx.withDatabase {
            for index in 1 ... 5 {
                try PlaylistStorageManager.shared.addTrackToPlaylist(
                    self.makeTrack("t\(index)", highResArtworkUrl: "https://x/\(index).png"),
                    toPlaylist: playlist.mediaId
                )
            }
        }

        let artwork = try ctx.withDatabase {
            TracklistArtworkResolver.shared.resolveComposedArtwork(
                mediaId: playlist.mediaId, mediaSourceId: "boppa.app"
            )
        }

        #expect(artwork.map(\.highResUrl) == [
            "https://x/1.png", "https://x/2.png", "https://x/3.png", "https://x/4.png",
        ])
    }

    @Test func resolveComposedArtworkSkipsDuplicateArtworkAcrossTracks() throws {
        let ctx = try Context()
        let playlist = try ctx
            .withDatabase { try PlaylistStorageManager.shared.createPlaylist(title: "Mix") }
        try ctx.withDatabase {
            try PlaylistStorageManager.shared.addTrackToPlaylist(
                self.makeTrack("t1", highResArtworkUrl: "https://x/a.png"),
                toPlaylist: playlist.mediaId
            )
            try PlaylistStorageManager.shared.addTrackToPlaylist(
                self.makeTrack("t2", highResArtworkUrl: "https://x/a.png"),
                toPlaylist: playlist.mediaId
            )
            try PlaylistStorageManager.shared.addTrackToPlaylist(
                self.makeTrack("t3", highResArtworkUrl: "https://x/b.png"),
                toPlaylist: playlist.mediaId
            )
            try PlaylistStorageManager.shared.addTrackToPlaylist(
                self.makeTrack("t4", highResArtworkUrl: "https://x/c.png"),
                toPlaylist: playlist.mediaId
            )
            try PlaylistStorageManager.shared.addTrackToPlaylist(
                self.makeTrack("t5", highResArtworkUrl: "https://x/d.png"),
                toPlaylist: playlist.mediaId
            )
        }

        let artwork = try ctx.withDatabase {
            TracklistArtworkResolver.shared.resolveComposedArtwork(
                mediaId: playlist.mediaId, mediaSourceId: "boppa.app"
            )
        }

        #expect(artwork.map(\.highResUrl) == [
            "https://x/a.png", "https://x/b.png", "https://x/c.png", "https://x/d.png",
        ])
    }

    @Test func resolveComposedArtworkReturnsFewerThanFourWhenTracklistLacksThatManyDistinctURLs(
    ) throws {
        let ctx = try Context()
        let playlist = try ctx
            .withDatabase { try PlaylistStorageManager.shared.createPlaylist(title: "Mix") }
        try ctx.withDatabase {
            try PlaylistStorageManager.shared.addTrackToPlaylist(
                self.makeTrack("t1", highResArtworkUrl: "https://x/a.png"),
                toPlaylist: playlist.mediaId
            )
            try PlaylistStorageManager.shared.addTrackToPlaylist(
                self.makeTrack("t2", highResArtworkUrl: "https://x/b.png"),
                toPlaylist: playlist.mediaId
            )
            try PlaylistStorageManager.shared.addTrackToPlaylist(
                self.makeTrack("t3"),
                toPlaylist: playlist.mediaId
            )
        }

        let artwork = try ctx.withDatabase {
            TracklistArtworkResolver.shared.resolveComposedArtwork(
                mediaId: playlist.mediaId, mediaSourceId: "boppa.app"
            )
        }

        #expect(artwork.map(\.highResUrl) == ["https://x/a.png", "https://x/b.png"])
    }

    @Test func resolveComposedArtworkScansBeyondInitialBatchWhenNeeded() throws {
        let ctx = try Context()
        let playlist = try ctx
            .withDatabase { try PlaylistStorageManager.shared.createPlaylist(title: "Long Mix") }
        try ctx.withDatabase {
            for index in 1 ... 8 {
                let art = index.isMultiple(of: 2) ? "https://x/even.png" : "https://x/odd.png"
                try PlaylistStorageManager.shared.addTrackToPlaylist(
                    self.makeTrack("t\(index)", highResArtworkUrl: art),
                    toPlaylist: playlist.mediaId
                )
            }
            try PlaylistStorageManager.shared.addTrackToPlaylist(
                self.makeTrack("t9", highResArtworkUrl: "https://x/c.png"),
                toPlaylist: playlist.mediaId
            )
            try PlaylistStorageManager.shared.addTrackToPlaylist(
                self.makeTrack("t10", highResArtworkUrl: "https://x/d.png"),
                toPlaylist: playlist.mediaId
            )
        }

        let artwork = try ctx.withDatabase {
            TracklistArtworkResolver.shared.resolveComposedArtwork(
                mediaId: playlist.mediaId, mediaSourceId: "boppa.app"
            )
        }

        #expect(artwork.map(\.highResUrl) == [
            "https://x/odd.png", "https://x/even.png", "https://x/c.png", "https://x/d.png",
        ])
    }
}
