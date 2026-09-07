@testable import Boppa
import Dependencies
internal import Foundation
import SQLiteData
import Testing

struct ArtistStorageManagerTests {
    // MARK: - Test Infrastructure

    /// Wraps an isolated, fully-migrated in-memory database for a single test, plus
    /// convenience accessors mirroring the tables ArtistStorageManager touches
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

        /// Scopes \.defaultDatabase for calls that go through self.database internally
        /// (fetchLibraryArtists, isArtistSaved, saveArtistToLibrary, removeArtistFromLibrary)
        /// rather than taking a db: param
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
    }

    // MARK: - Fixtures

    private func makeArtist(
        _ mediaId: String,
        source: String = "src",
        name: String = "Artist Name",
        lowResArtworkUrl: String? = nil,
        highResArtworkUrl: String? = nil,
        url: String? = nil
    ) -> Artist {
        Artist(
            mediaId: mediaId, mediaSourceId: source, name: name,
            lowResArtworkUrl: lowResArtworkUrl, highResArtworkUrl: highResArtworkUrl, url: url
        )
    }

    private func makeTrack(
        _ mediaId: String,
        source: String = "src",
        artists: [Artist] = []
    ) -> Track {
        Track(
            mediaId: mediaId,
            mediaSourceId: source,
            title: "Track Title",
            artists: artists
        )
    }

    // MARK: - fetchLibraryArtists

    @Test func fetchLibraryArtistsReturnsEmptyWhenNoArtists() throws {
        let ctx = try Context()

        let artists = try ctx.withDatabase { ArtistStorageManager.shared.fetchLibraryArtists() }

        #expect(artists.isEmpty)
    }

    @Test func fetchLibraryArtistsReturnsOnlySavedArtists() throws {
        let ctx = try Context()
        try ctx.withDatabase {
            try ArtistStorageManager.shared.saveArtistToLibrary(self.makeArtist("a1"))
        }
        try ctx.write { db in
            try ArtistStorageManager.shared.markArtistRecentlyViewed(
                self.makeArtist("a2"), viewedAt: 1, db: db
            )
        }

        let artists = try ctx.withDatabase { ArtistStorageManager.shared.fetchLibraryArtists() }

        #expect(artists.map(\.mediaId) == ["a1"])
    }

    // MARK: - isArtistSaved

    @Test func isArtistSavedReturnsFalseForNonexistentArtist() throws {
        let ctx = try Context()

        let isSaved = try ctx.withDatabase {
            ArtistStorageManager.shared.isArtistSaved(mediaId: "ghost", mediaSourceId: "src")
        }

        #expect(isSaved == false)
    }

    @Test func isArtistSavedReturnsFalseWhenArtistExistsButNotSaved() throws {
        let ctx = try Context()
        try ctx.write { db in
            try ArtistStorageManager.shared.markArtistRecentlyViewed(
                self.makeArtist("a1"), viewedAt: 1, db: db
            )
        }

        let isSaved = try ctx.withDatabase {
            ArtistStorageManager.shared.isArtistSaved(mediaId: "a1", mediaSourceId: "src")
        }

        #expect(isSaved == false)
    }

    @Test func isArtistSavedReturnsTrueWhenSaved() throws {
        let ctx = try Context()
        try ctx.withDatabase {
            try ArtistStorageManager.shared.saveArtistToLibrary(self.makeArtist("a1"))
        }

        let isSaved = try ctx.withDatabase {
            ArtistStorageManager.shared.isArtistSaved(mediaId: "a1", mediaSourceId: "src")
        }

        #expect(isSaved == true)
    }

    // MARK: - saveArtistToLibrary

    @Test func saveArtistToLibraryInsertsNewArtistAndMarksSaved() throws {
        let ctx = try Context()
        let a1 = self.makeArtist(
            "a1", name: "New Artist", lowResArtworkUrl: "https://x/art.png", url: "https://x/a1"
        )

        try ctx.withDatabase { try ArtistStorageManager.shared.saveArtistToLibrary(a1) }

        let stored = try #require(try ctx.artist("a1"))
        #expect(stored.name == "New Artist")
        #expect(stored.lowResArtworkUrl == "https://x/art.png")
        #expect(stored.url == "https://x/a1")
        #expect(stored.isSavedToLibrary == true)
    }

    @Test func saveArtistToLibraryOnExistingArtistUpdatesScalarsAndMarksSaved() throws {
        let ctx = try Context()
        try ctx.write { db in
            try ArtistStorageManager.shared.markArtistRecentlyViewed(
                self.makeArtist("a1", name: "Old Name"), viewedAt: 1, db: db
            )
        }

        try ctx.withDatabase {
            try ArtistStorageManager.shared.saveArtistToLibrary(
                self.makeArtist("a1", name: "New Name")
            )
        }

        let stored = try #require(try ctx.artist("a1"))
        #expect(stored.name == "New Name")
        #expect(stored.isSavedToLibrary == true)
        #expect(stored.isRecent == true)
    }

    // MARK: - removeArtistFromLibrary

    @Test func removeArtistFromLibraryDeletesUnreferencedArtist() throws {
        let ctx = try Context()
        try ctx.withDatabase {
            try ArtistStorageManager.shared.saveArtistToLibrary(self.makeArtist("a1"))
        }

        try ctx.withDatabase {
            try ArtistStorageManager.shared.removeArtistFromLibrary(
                mediaId: "a1", mediaSourceId: "src"
            )
        }

        #expect(try ctx.artist("a1") == nil)
    }

    @Test func removeArtistFromLibraryKeepsArtistReferencedByTrack() throws {
        let ctx = try Context()
        let a1 = self.makeArtist("a1")
        try ctx.write { db in
            try TrackStorageManager.shared.upsertTrack(self.makeTrack("t1", artists: [a1]), db: db)
        }
        try ctx.withDatabase { try ArtistStorageManager.shared.saveArtistToLibrary(a1) }

        try ctx.withDatabase {
            try ArtistStorageManager.shared.removeArtistFromLibrary(
                mediaId: "a1", mediaSourceId: "src"
            )
        }

        let stored = try #require(try ctx.artist("a1"))
        #expect(stored.isSavedToLibrary == false)
    }

    @Test func removeArtistFromLibraryKeepsRecentArtistButClearsFlag() throws {
        let ctx = try Context()
        let a1 = self.makeArtist("a1")
        try ctx.write { db in
            try ArtistStorageManager.shared.markArtistRecentlyViewed(a1, viewedAt: 1, db: db)
        }
        try ctx.withDatabase { try ArtistStorageManager.shared.saveArtistToLibrary(a1) }

        try ctx.withDatabase {
            try ArtistStorageManager.shared.removeArtistFromLibrary(
                mediaId: "a1", mediaSourceId: "src"
            )
        }

        let stored = try #require(try ctx.artist("a1"))
        #expect(stored.isSavedToLibrary == false)
        #expect(stored.isRecent == true)
    }

    // MARK: - upsertArtist

    @Test func upsertArtistInsertsNewArtist() throws {
        let ctx = try Context()
        let a1 = self.makeArtist(
            "a1", name: "Artist One", lowResArtworkUrl: "https://x/art.png", url: "https://x/a1"
        )

        try ctx.write { db in try ArtistStorageManager.shared.upsertArtist(a1, db: db) }

        let stored = try #require(try ctx.artist("a1"))
        #expect(stored.name == "Artist One")
        #expect(stored.lowResArtworkUrl == "https://x/art.png")
        #expect(stored.url == "https://x/a1")
        #expect(stored.isSavedToLibrary == false)
    }

    @Test func upsertArtistPartialUpdateIgnoresEmptyNameAndNilArtworkAndNilURL() throws {
        let ctx = try Context()
        let original = self.makeArtist(
            "a1", name: "Real Name", lowResArtworkUrl: "https://x/art.png", url: "https://x/a1"
        )
        try ctx.write { db in try ArtistStorageManager.shared.upsertArtist(original, db: db) }

        let resynced = self.makeArtist("a1", name: "", lowResArtworkUrl: nil, url: nil)
        try ctx.write { db in try ArtistStorageManager.shared.upsertArtist(resynced, db: db) }

        let stored = try #require(try ctx.artist("a1"))
        #expect(stored.name == "Real Name")
        #expect(stored.lowResArtworkUrl == "https://x/art.png")
        #expect(stored.url == "https://x/a1")
    }

    // MARK: - deleteArtistIfOrphaned

    @Test func deleteArtistIfOrphanedNoOpForNonexistentArtist() throws {
        let ctx = try Context()

        try ctx.write { db in
            try ArtistStorageManager.shared.deleteArtistIfOrphaned(
                mediaId: "ghost", mediaSourceId: "src", db: db
            )
        }
    }

    @Test func deleteArtistIfOrphanedKeepsArtistReferencedByTrack() throws {
        let ctx = try Context()
        let a1 = self.makeArtist("a1")
        try ctx.write { db in
            try TrackStorageManager.shared.upsertTrack(self.makeTrack("t1", artists: [a1]), db: db)
        }

        try ctx.write { db in
            try ArtistStorageManager.shared.deleteArtistIfOrphaned(
                mediaId: "a1", mediaSourceId: "src", db: db
            )
        }

        #expect(try ctx.artist("a1") != nil)
    }

    @Test(
        arguments: [
            (isSaved: false, isRecent: false, shouldSurvive: false),
            (isSaved: true, isRecent: false, shouldSurvive: true),
            (isSaved: false, isRecent: true, shouldSurvive: true),
            (isSaved: true, isRecent: true, shouldSurvive: true),
        ]
    )
    func deleteArtistIfOrphanedRespectsSavedAndRecentFlags(
        _ params: (isSaved: Bool, isRecent: Bool, shouldSurvive: Bool)
    ) throws {
        let ctx = try Context()
        try ctx.write { db in
            try ArtistStorageManager.shared.upsertArtist(self.makeArtist("a1"), db: db)
        }
        try ctx.write { db in
            try StoredArtist.update {
                $0.isSavedToLibrary = params.isSaved
                $0.isRecent = params.isRecent
            }
            .where { $0.mediaId.eq("a1").and($0.mediaSourceId.eq("src")) }
            .execute(db)
        }

        try ctx.write { db in
            try ArtistStorageManager.shared.deleteArtistIfOrphaned(
                mediaId: "a1", mediaSourceId: "src", db: db
            )
        }

        #expect(try (ctx.artist("a1") != nil) == params.shouldSurvive)
    }

    // MARK: - Recents

    @Test func markArtistRecentlyViewedInsertsArtistAndSetsFlag() throws {
        let ctx = try Context()
        let a1 = self.makeArtist("a1", name: "Some Artist")

        try ctx.write { db in
            try ArtistStorageManager.shared.markArtistRecentlyViewed(a1, viewedAt: 55, db: db)
        }

        let stored = try #require(try ctx.artist("a1"))
        #expect(stored.isRecent == true)
        #expect(stored.lastViewedTimestamp == 55)
    }

    @Test func markArtistRecentlyViewedUpdatesTimestampOnRevisit() throws {
        let ctx = try Context()
        let a1 = self.makeArtist("a1")
        try ctx.write { db in
            try ArtistStorageManager.shared.markArtistRecentlyViewed(a1, viewedAt: 100, db: db)
        }

        try ctx.write { db in
            try ArtistStorageManager.shared.markArtistRecentlyViewed(a1, viewedAt: 200, db: db)
        }

        let stored = try #require(try ctx.artist("a1"))
        #expect(stored.lastViewedTimestamp == 200)
    }

    @Test func unmarkArtistRecentlyViewedDeletesOrphanedArtist() throws {
        let ctx = try Context()
        let a1 = self.makeArtist("a1")
        try ctx.write { db in
            try ArtistStorageManager.shared.markArtistRecentlyViewed(a1, viewedAt: 1, db: db)
        }

        try ctx.write { db in
            try ArtistStorageManager.shared.unmarkArtistRecentlyViewed(
                mediaId: "a1", mediaSourceId: "src", db: db
            )
        }

        #expect(try ctx.artist("a1") == nil)
    }

    @Test func unmarkArtistRecentlyViewedKeepsArtistReferencedByTrack() throws {
        let ctx = try Context()
        let a1 = self.makeArtist("a1")
        try ctx.write { db in
            try TrackStorageManager.shared.upsertTrack(self.makeTrack("t1", artists: [a1]), db: db)
            try ArtistStorageManager.shared.markArtistRecentlyViewed(a1, viewedAt: 1, db: db)
        }

        try ctx.write { db in
            try ArtistStorageManager.shared.unmarkArtistRecentlyViewed(
                mediaId: "a1", mediaSourceId: "src", db: db
            )
        }

        #expect(try ctx.artist("a1") != nil)
    }

    @Test func unmarkArtistRecentlyViewedKeepsSavedToLibraryArtist() throws {
        let ctx = try Context()
        let a1 = self.makeArtist("a1")
        try ctx.withDatabase { try ArtistStorageManager.shared.saveArtistToLibrary(a1) }
        try ctx.write { db in
            try ArtistStorageManager.shared.markArtistRecentlyViewed(a1, viewedAt: 1, db: db)
        }

        try ctx.write { db in
            try ArtistStorageManager.shared.unmarkArtistRecentlyViewed(
                mediaId: "a1", mediaSourceId: "src", db: db
            )
        }

        let stored = try #require(try ctx.artist("a1"))
        #expect(stored.isRecent == false)
        #expect(stored.isSavedToLibrary == true)
    }
}
