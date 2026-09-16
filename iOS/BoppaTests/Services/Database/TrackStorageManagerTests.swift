@testable import Boppa
import Dependencies
internal import Foundation
import SQLiteData
import Testing

struct TrackStorageManagerTests {
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

        func artist(_ mediaId: String, _ source: String = "src") throws -> StoredArtist? {
            try self.db.read { db in
                try StoredArtist.where { $0.mediaId.eq(mediaId).and($0.mediaSourceId.eq(source)) }
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

    // MARK: - fetchLibraryTracks

    @Test func fetchLibraryTracksReturnsEmptyWhenNoTracks() throws {
        let ctx = try Context()

        let tracks = try ctx.withDatabase { TrackStorageManager.shared.fetchLibraryTracks() }

        #expect(tracks.isEmpty)
    }

    @Test func fetchLibraryTracksReturnsAllStoredTracks() throws {
        let ctx = try Context()
        try ctx.write { db in
            try TrackStorageManager.shared.upsertTracks([self.makeTrack("t1")], db: db)
            try TrackStorageManager.shared.markSavedToLibrary([self.makeTrack("t1")], db: db)
            try TrackStorageManager.shared.upsertTracks([self.makeTrack("t2")], db: db)
            try TrackStorageManager.shared.markSavedToLibrary([self.makeTrack("t2")], db: db)
        }

        let tracks = try ctx.withDatabase { TrackStorageManager.shared.fetchLibraryTracks() }

        #expect(Set(tracks.map(\.mediaId)) == ["t1", "t2"])
    }

    // MARK: - upsertTrack: insert

    @Test func upsertTrackInsertsNewTrackWithArtistsAndAlbums() throws {
        let ctx = try Context()
        let t1 = self.makeTrack(
            "t1",
            title: "Song",
            subtitle: "Sub",
            duration: 200_000,
            lowResArtworkUrl: "https://x/art.png",
            url: "https://x/song.mp3",
            artists: [self.makeArtist("a1", name: "Artist One")],
            albums: [self.makeAlbum("al1", title: "Album One")]
        )
        try ctx.write { db in try TrackStorageManager.shared.upsertTracks([t1], db: db) }

        let stored = try #require(try ctx.track("t1"))
        #expect(stored.title == "Song")
        #expect(stored.subtitle == "Sub")
        #expect(stored.duration == 200_000)
        #expect(stored.lowResArtworkUrl == "https://x/art.png")
        #expect(stored.url == "https://x/song.mp3")
        #expect(stored.isRecent == false)

        #expect(try ctx.artist("a1") != nil)
        #expect(try ctx.tracklist("al1") != nil)
        #expect(try ctx.trackArtistRefs("t1").count == 1)
        #expect(try ctx.trackAlbumRefs("t1").count == 1)
    }

    @Test func upsertTrackPersistsArtistAndAlbumURL() throws {
        let ctx = try Context()
        let t1 = self.makeTrack(
            "t1",
            artists: [
                self.makeArtist("a1", name: "Artist One", url: "https://example.com/artists/a1"),
            ],
            albums: [self.makeAlbum("al1", url: "https://example.com/albums/al1")]
        )
        try ctx.write { db in try TrackStorageManager.shared.upsertTracks([t1], db: db) }

        let artist = try #require(try ctx.artist("a1"))
        #expect(artist.url == "https://example.com/artists/a1")

        let album = try #require(try ctx.tracklist("al1"))
        #expect(album.url == "https://example.com/albums/al1")
    }

    // MARK: - upsertTrack: change detection

    @Test func upsertTracksAlwaysReplacesJoinsEvenWithIdenticalContent() throws {
        let ctx = try Context()
        let t1 = self.makeTrack("t1", artists: [self.makeArtist("a1", name: "Artist One")])
        try ctx.write { db in try TrackStorageManager.shared.upsertTracks([t1], db: db) }
        try ctx.write { db in
            try StoredTrackArtist.update { $0.sortOrder = "sentinel" }
                .where { $0.trackMediaId.eq("t1").and($0.trackMediaSourceId.eq("src")) }
                .execute(db)
        }

        try ctx.write { db in try TrackStorageManager.shared.upsertTracks([t1], db: db) }

        let refs = try ctx.trackArtistRefs("t1")
        #expect(refs.count == 1)
        #expect(refs.first?.sortOrder != "sentinel")
    }

    @Test func upsertTrackChangedTitleUpdatesScalarsAndRegeneratesJoins() throws {
        let ctx = try Context()
        let original = self.makeTrack(
            "t1", title: "Old Title", artists: [self.makeArtist("a1", name: "Artist One")]
        )
        try ctx.write { db in try TrackStorageManager.shared.upsertTracks([original], db: db) }
        try ctx.write { db in
            try StoredTrackArtist.update { $0.sortOrder = "sentinel" }
                .where { $0.trackMediaId.eq("t1").and($0.trackMediaSourceId.eq("src")) }
                .execute(db)
        }

        let updated = self.makeTrack(
            "t1", title: "New Title", artists: [self.makeArtist("a1", name: "Artist One")]
        )
        try ctx.write { db in try TrackStorageManager.shared.upsertTracks([updated], db: db) }

        let stored = try #require(try ctx.track("t1"))
        #expect(stored.title == "New Title")
        let refs = try ctx.trackArtistRefs("t1")
        #expect(refs.first?.sortOrder != "sentinel")
    }

    @Test func upsertTrackPreservesArtistURLWhenResyncOmitsIt() throws {
        let ctx = try Context()
        let t1 = self.makeTrack(
            "t1",
            artists: [self.makeArtist("a1", name: "Artist One", url: "https://example.com/a1")]
        )
        try ctx.write { db in try TrackStorageManager.shared.upsertTracks([t1], db: db) }

        let resynced = self.makeTrack(
            "t1", artists: [self.makeArtist("a1", name: "Artist One", url: nil)]
        )
        try ctx.write { db in try TrackStorageManager.shared.upsertTracks([resynced], db: db) }

        let artist = try #require(try ctx.artist("a1"))
        #expect(artist.url == "https://example.com/a1")
    }

    @Test func upsertTrackPreservesAlbumURLWhenResyncOmitsIt() throws {
        let ctx = try Context()
        let t1 = self.makeTrack(
            "t1", albums: [self.makeAlbum("al1", url: "https://example.com/al1")]
        )
        try ctx.write { db in try TrackStorageManager.shared.upsertTracks([t1], db: db) }

        let resynced = self.makeTrack(
            "t1", albums: [self.makeAlbum("al1", url: nil)]
        )
        try ctx.write { db in try TrackStorageManager.shared.upsertTracks([resynced], db: db) }

        let album = try #require(try ctx.tracklist("al1"))
        #expect(album.url == "https://example.com/al1")
    }

    @Test func upsertTrackDetectsAndPersistsArtistURLWhenNewlyProvided() throws {
        let ctx = try Context()
        let t1 = self.makeTrack(
            "t1", artists: [self.makeArtist("a1", name: "Artist One", url: nil)]
        )
        try ctx.write { db in try TrackStorageManager.shared.upsertTracks([t1], db: db) }
        #expect(try ctx.artist("a1")?.url == nil)

        let resynced = self.makeTrack(
            "t1",
            artists: [self.makeArtist("a1", name: "Artist One", url: "https://example.com/a1")]
        )
        try ctx.write { db in try TrackStorageManager.shared.upsertTracks([resynced], db: db) }

        #expect(try ctx.artist("a1")?.url == "https://example.com/a1")
    }

    @Test func upsertTrackDetectsAndPersistsAlbumURLWhenNewlyProvided() throws {
        let ctx = try Context()
        let t1 = self.makeTrack("t1", albums: [self.makeAlbum("al1", url: nil)])
        try ctx.write { db in try TrackStorageManager.shared.upsertTracks([t1], db: db) }
        #expect(try ctx.tracklist("al1")?.url == nil)

        let resynced = self.makeTrack(
            "t1", albums: [self.makeAlbum("al1", url: "https://example.com/al1")]
        )
        try ctx.write { db in try TrackStorageManager.shared.upsertTracks([resynced], db: db) }

        #expect(try ctx.tracklist("al1")?.url == "https://example.com/al1")
    }

    // MARK: - upsertTrack: artist orphaning

    @Test func upsertTrackReplacingArtistDeletesOldUnsharedArtist() throws {
        let ctx = try Context()
        let t1 = self.makeTrack("t1", artists: [self.makeArtist("a1", name: "Old Artist")])
        try ctx.write { db in try TrackStorageManager.shared.upsertTracks([t1], db: db) }
        #expect(try ctx.artist("a1") != nil)

        let t1Updated = self.makeTrack("t1", artists: [self.makeArtist("a2", name: "New Artist")])
        try ctx.write { db in try TrackStorageManager.shared.upsertTracks([t1Updated], db: db) }

        #expect(try ctx.artist("a1") == nil)
        #expect(try ctx.artist("a2") != nil)
    }

    @Test func upsertTrackReplacingArtistKeepsOldArtistIfSharedByAnotherTrack() throws {
        let ctx = try Context()
        let shared = self.makeArtist("a1", name: "Shared Artist")
        try ctx.write { db in
            try TrackStorageManager.shared.upsertTracks(
                [self.makeTrack("t1", artists: [shared])], db: db
            )
            try TrackStorageManager.shared.upsertTracks(
                [self.makeTrack("t2", artists: [shared])], db: db
            )
        }

        let t1Updated = self.makeTrack("t1", artists: [])
        try ctx.write { db in try TrackStorageManager.shared.upsertTracks([t1Updated], db: db) }

        #expect(try ctx.artist("a1") != nil)
        #expect(try ctx.trackArtistRefs("t1").isEmpty)
    }

    @Test func upsertArtistPartialUpdateIgnoresEmptyNameAndNilArtworkAndNilURL() throws {
        let ctx = try Context()
        let t1 = self.makeTrack(
            "t1",
            title: "Title A",
            artists: [
                self.makeArtist(
                    "a1", name: "Real Name", lowResArtworkUrl: "https://x/art.png",
                    url: "https://x/a1"
                ),
            ]
        )
        try ctx.write { db in try TrackStorageManager.shared.upsertTracks([t1], db: db) }

        let t1Updated = self.makeTrack(
            "t1", title: "Title B",
            artists: [self.makeArtist("a1", name: "", lowResArtworkUrl: nil, url: nil)]
        )
        try ctx.write { db in try TrackStorageManager.shared.upsertTracks([t1Updated], db: db) }

        let artist = try #require(try ctx.artist("a1"))
        #expect(artist.name == "Real Name")
        #expect(artist.lowResArtworkUrl == "https://x/art.png")
        #expect(artist.url == "https://x/a1")
    }

    // MARK: - upsertTrack: album orphaning

    @Test func upsertTrackReplacingAlbumDeletesOldUnsharedStubAlbum() throws {
        let ctx = try Context()
        let t1 = self.makeTrack("t1", albums: [self.makeAlbum("al1", title: "Old Album")])
        try ctx.write { db in try TrackStorageManager.shared.upsertTracks([t1], db: db) }
        #expect(try ctx.tracklist("al1") != nil)

        let t1Updated = self.makeTrack("t1", albums: [self.makeAlbum("al2", title: "New Album")])
        try ctx.write { db in try TrackStorageManager.shared.upsertTracks([t1Updated], db: db) }

        #expect(try ctx.tracklist("al1") == nil)
        #expect(try ctx.tracklist("al2") != nil)
    }

    @Test func upsertTrackReplacingAlbumKeepsAlbumIfSavedToLibrary() throws {
        let ctx = try Context()
        let t1 = self.makeTrack("t1", albums: [self.makeAlbum("al1", title: "Saved Album")])
        try ctx.write { db in try TrackStorageManager.shared.upsertTracks([t1], db: db) }
        try ctx.write { db in
            try StoredTracklist.update { $0.isSavedToLibrary = true }
                .where { $0.mediaId.eq("al1").and($0.mediaSourceId.eq("src")) }
                .execute(db)
        }

        let t1Updated = self.makeTrack("t1", albums: [])
        try ctx.write { db in try TrackStorageManager.shared.upsertTracks([t1Updated], db: db) }

        #expect(try ctx.tracklist("al1") != nil)
    }

    @Test func upsertTrackNewAlbumStubDefaultsToNotSavedToLibrary() throws {
        let ctx = try Context()
        let t1 = self.makeTrack("t1", albums: [self.makeAlbum("al1")])
        try ctx.write { db in try TrackStorageManager.shared.upsertTracks([t1], db: db) }

        let album = try #require(try ctx.tracklist("al1"))
        #expect(album.isSavedToLibrary == false)
    }

    @Test func upsertTracklistStubPartialUpdateIgnoresEmptyTitleAndNilURL() throws {
        let ctx = try Context()
        let t1 = self.makeTrack(
            "t1",
            albums: [
                self.makeAlbum("al1", title: "Real Album", url: "https://x/al1"),
            ]
        )
        try ctx.write { db in try TrackStorageManager.shared.upsertTracks([t1], db: db) }

        let t1Updated = self.makeTrack(
            "t1",
            title: "New Track Title",
            albums: [self.makeAlbum("al1", title: "", url: nil)]
        )
        try ctx.write { db in try TrackStorageManager.shared.upsertTracks([t1Updated], db: db) }

        let album = try #require(try ctx.tracklist("al1"))
        #expect(album.title == "Real Album")
        #expect(album.url == "https://x/al1")
    }

    @Test func upsertTrackWithInvalidAlbumTracklistTypeThrows() throws {
        let ctx = try Context()
        let t1 = self.makeTrack("t1", albums: [self.makeAlbum("al1", type: .artistSongs)])

        #expect(throws: (any Error).self) {
            try ctx.write { db in try TrackStorageManager.shared.upsertTracks([t1], db: db) }
        }
    }

    // MARK: - replaceTrackArtists / replaceTrackAlbums

    @Test func replaceTrackArtistsPreservesInputOrder() throws {
        let ctx = try Context()
        let artists = [
            self.makeArtist("a1", name: "First"),
            self.makeArtist("a2", name: "Second"),
            self.makeArtist("a3", name: "Third"),
        ]
        let t1 = self.makeTrack("t1", artists: artists)
        try ctx.write { db in try TrackStorageManager.shared.upsertTracks([t1], db: db) }

        let stored = try #require(try ctx.track("t1"))
        let loaded = try ctx.read { db in
            try ArtistStorageManager.shared.fetchStoredArtistsForTracks(
                [stored.toTrack()],
                db: db
            ).map(\.1)
        }

        #expect(loaded.map(\.name) == ["First", "Second", "Third"])
    }

    @Test func replaceTrackAlbumsPreservesInputOrder() throws {
        let ctx = try Context()
        let albums = [
            self.makeAlbum("al1", title: "First"), self.makeAlbum("al2", title: "Second"),
        ]
        let t1 = self.makeTrack("t1", albums: albums)
        try ctx.write { db in try TrackStorageManager.shared.upsertTracks([t1], db: db) }

        let stored = try #require(try ctx.track("t1"))
        let loaded = try ctx.read { db in
            try TracklistStorageManager.shared.fetchStoredAlbumsForTracks(
                [stored.toTrack()],
                db: db
            ).map(\.1)
        }

        #expect(loaded.map(\.title) == ["First", "Second"])
    }

    @Test func replaceTrackArtistsWithEmptyArrayRemovesAllAndOrphansUnshared() throws {
        let ctx = try Context()
        let t1 = self.makeTrack("t1", artists: [self.makeArtist("a1", name: "Solo Artist")])
        try ctx.write { db in try TrackStorageManager.shared.upsertTracks([t1], db: db) }

        let stored = try #require(try ctx.track("t1"))
        try ctx.write { db in
            try TrackStorageManager.shared.replaceTrackArtists(track: stored, artists: [], db: db)
        }

        #expect(try ctx.trackArtistRefs("t1").isEmpty)
        #expect(try ctx.artist("a1") == nil)
    }

    // MARK: - deleteTrackStubsIfOrphaned

    @Test func deleteTrackStubsIfOrphanedNoOpForNonexistentTrack() throws {
        let ctx = try Context()

        try ctx.write { db in
            try TrackStorageManager.shared.deleteTrackStubsIfOrphaned(
                [self.makeTrack("ghost")],
                db: db
            )
        }
    }

    @Test func deleteTrackStubsIfOrphanedNoOpWhenTrackStillInPlaylist() throws {
        let ctx = try Context()
        let t1 = self.makeTrack("t1")
        try ctx.withDatabase { try PlaylistStorageManager.shared.addTrackToPlaylist(
            t1,
            toPlaylist: "likes"
        ) }
        try ctx.write { db in
            try TrackStorageManager.shared.deleteTrackStubsIfOrphaned([t1], db: db)
        }

        #expect(try ctx.track("t1") != nil)
    }

    @Test func deleteTrackStubsIfOrphanedNoOpWhenTrackIsRecent() throws {
        let ctx = try Context()
        let t1 = self.makeTrack("t1")
        try ctx.write { db in
            try RecentsStorageManager.shared.markTrackRecentlyPlayed(t1, playedAt: 100, db: db)
        }

        try ctx.write { db in
            try TrackStorageManager.shared.deleteTrackStubsIfOrphaned([t1], db: db)
        }

        #expect(try ctx.track("t1") != nil)
    }

    @Test func deleteTrackStubsIfOrphanedDeletesTrackAndCascadesUnsharedArtistAndAlbum() throws {
        let ctx = try Context()
        let t1 = self.makeTrack(
            "t1", artists: [self.makeArtist("a1")], albums: [self.makeAlbum("al1")]
        )
        try ctx.write { db in try TrackStorageManager.shared.upsertTracks([t1], db: db) }
        try ctx.write { db in
            try TrackStorageManager.shared.deleteTrackStubsIfOrphaned([t1], db: db)
        }

        #expect(try ctx.track("t1") == nil)
        #expect(try ctx.artist("a1") == nil)
        #expect(try ctx.tracklist("al1") == nil)
    }

    @Test func deleteTrackStubsIfOrphanedKeepsArtistSharedAcrossTracks() throws {
        let ctx = try Context()
        let shared = self.makeArtist("a1")
        try ctx.write { db in
            try TrackStorageManager.shared.upsertTracks(
                [self.makeTrack("t1", artists: [shared])], db: db
            )
            try TrackStorageManager.shared.upsertTracks(
                [self.makeTrack("t2", artists: [shared])], db: db
            )
        }

        try ctx.write { db in
            try TrackStorageManager.shared.deleteTrackStubsIfOrphaned(
                [self.makeTrack("t1")],
                db: db
            )
        }

        #expect(try ctx.artist("a1") != nil)
    }

    @Test func deleteTrackStubsIfOrphanedKeepsAlbumSharedAcrossTracks() throws {
        let ctx = try Context()
        let shared = self.makeAlbum("al1")
        try ctx.write { db in
            try TrackStorageManager.shared.upsertTracks(
                [self.makeTrack("t1", albums: [shared])], db: db
            )
            try TrackStorageManager.shared.upsertTracks(
                [self.makeTrack("t2", albums: [shared])], db: db
            )
        }

        try ctx.write { db in
            try TrackStorageManager.shared.deleteTrackStubsIfOrphaned(
                [self.makeTrack("t1")],
                db: db
            )
        }

        #expect(try ctx.tracklist("al1") != nil)
    }

    @Test func deleteTrackStubsIfOrphanedDeletesMultipleTracksInOneBatch() throws {
        let ctx = try Context()
        let t1 = self.makeTrack("t1", artists: [self.makeArtist("a1")])
        let t2 = self.makeTrack("t2", artists: [self.makeArtist("a2")])
        try ctx.write { db in
            try TrackStorageManager.shared.upsertTracks([t1], db: db)
            try TrackStorageManager.shared.upsertTracks([t2], db: db)
        }

        try ctx.write { db in
            try TrackStorageManager.shared.deleteTrackStubsIfOrphaned([t1, t2], db: db)
        }

        #expect(try ctx.track("t1") == nil)
        #expect(try ctx.track("t2") == nil)
        #expect(try ctx.artist("a1") == nil)
        #expect(try ctx.artist("a2") == nil)
    }

    @Test(
        arguments: [
            (isSaved: false, isRecent: false, shouldSurvive: false),
            (isSaved: true, isRecent: false, shouldSurvive: true),
            (isSaved: false, isRecent: true, shouldSurvive: true),
            (isSaved: true, isRecent: true, shouldSurvive: true),
        ]
    )
    func albumStubOrphanCleanupRespectsSavedAndRecentFlags(
        _ params: (isSaved: Bool, isRecent: Bool, shouldSurvive: Bool)
    ) throws {
        let ctx = try Context()
        try ctx.write { db in
            try TrackStorageManager.shared.upsertTracks(
                [self.makeTrack("t1", albums: [self.makeAlbum("al1")])], db: db
            )
        }
        try ctx.write { db in
            try StoredTracklist.update {
                $0.isSavedToLibrary = params.isSaved
                $0.isRecent = params.isRecent
            }
            .where { $0.mediaId.eq("al1").and($0.mediaSourceId.eq("src")) }
            .execute(db)
        }

        let stored = try #require(try ctx.track("t1"))
        try ctx.write { db in
            try TrackStorageManager.shared.replaceTrackAlbums(track: stored, albums: [], db: db)
        }

        #expect(try (ctx.tracklist("al1") != nil) == params.shouldSurvive)
    }

    // MARK: - fetchStoredArtistsForTracks / fetchStoredAlbumsForTracks

    @Test func fetchStoredArtistsForTracksReturnsEmptyForTrackWithNoArtists() throws {
        let ctx = try Context()
        try ctx.write { db in
            try TrackStorageManager.shared.upsertTracks([self.makeTrack("t1")], db: db)
        }
        let stored = try #require(try ctx.track("t1"))
        let artists = try ctx.read { db in
            try ArtistStorageManager.shared.fetchStoredArtistsForTracks([stored.toTrack()], db: db)
        }
        #expect(artists.isEmpty)
    }

    @Test func fetchStoredArtistsForTracksBatchesAndScopesByMediaSource() throws {
        let ctx = try Context()
        try ctx.write { db in
            try TrackStorageManager.shared.upsertTracks(
                [self.makeTrack("t1", artists: [self.makeArtist("a1", name: "Track One Artist")])],
                db: db
            )
            try TrackStorageManager.shared.upsertTracks(
                [self.makeTrack(
                    "t1", source: "other-src",
                    artists: [self.makeArtist(
                        "a2",
                        source: "other-src",
                        name: "Other Source Artist"
                    )]
                )],
                db: db
            )
        }
        let stored1 = try #require(try ctx.track("t1"))
        let stored2 = try #require(try ctx.track("t1", "other-src"))

        let result = try ctx.read { db in
            try ArtistStorageManager.shared.fetchStoredArtistsForTracks(
                [stored1.toTrack(), stored2.toTrack()],
                db: db
            )
        }

        #expect(
            result.filter { $0.0.mediaSourceId == "src" }.map(\.1.name) == ["Track One Artist"]
        )
        #expect(
            result.filter { $0.0.mediaSourceId == "other-src" }.map(\.1.name)
                == ["Other Source Artist"]
        )
    }

    @Test func fetchStoredAlbumsForTracksReturnsEmptyForTrackWithNoAlbums() throws {
        let ctx = try Context()
        try ctx.write { db in
            try TrackStorageManager.shared.upsertTracks([self.makeTrack("t1")], db: db)
        }
        let stored = try #require(try ctx.track("t1"))
        let albums = try ctx.read { db in
            try TracklistStorageManager.shared.fetchStoredAlbumsForTracks(
                [stored.toTrack()],
                db: db
            )
        }
        #expect(albums.isEmpty)
    }

    // MARK: - Recents: tracklists

    @Test func unmarkTracklistRecentlyViewedDeletesUnsavedUnreferencedStub() throws {
        let ctx = try Context()
        try ctx.write { db in
            try TrackStorageManager.shared.upsertTracks(
                [self.makeTrack("t1", albums: [self.makeAlbum("al1")])], db: db
            )
        }
        try ctx.write { db in
            try StoredTracklist.update { $0.isRecent = true }
                .where { $0.mediaId.eq("al1").and($0.mediaSourceId.eq("src")) }
                .execute(db)
        }
        let stored = try #require(try ctx.track("t1"))
        try ctx.write { db in
            try TrackStorageManager.shared.replaceTrackAlbums(track: stored, albums: [], db: db)
        }
        #expect(try ctx.tracklist("al1") != nil)

        try ctx.write { db in
            try RecentsStorageManager.shared.unmarkTracklistRecentlyViewed(
                self.makeAlbum("al1"), db: db
            )
        }

        #expect(try ctx.tracklist("al1") == nil)
    }

    @Test func unmarkTracklistRecentlyViewedKeepsSavedToLibraryAlbum() throws {
        let ctx = try Context()
        try ctx.write { db in
            try TrackStorageManager.shared.upsertTracks(
                [self.makeTrack("t1", albums: [self.makeAlbum("al1")])], db: db
            )
        }
        try ctx.write { db in
            try StoredTracklist.update {
                $0.isSavedToLibrary = true
                $0.isRecent = true
            }
            .where { $0.mediaId.eq("al1").and($0.mediaSourceId.eq("src")) }
            .execute(db)
        }

        try ctx.write { db in
            try RecentsStorageManager.shared.unmarkTracklistRecentlyViewed(
                self.makeAlbum("al1"), db: db
            )
        }

        let album = try #require(try ctx.tracklist("al1"))
        #expect(album.isRecent == false)
    }

    @Test func unmarkTracklistRecentlyViewedNoOpForNonexistentTracklist() throws {
        let ctx = try Context()

        try ctx.write { db in
            try RecentsStorageManager.shared.unmarkTracklistRecentlyViewed(
                self.makeAlbum("ghost"), db: db
            )
        }
    }
}
