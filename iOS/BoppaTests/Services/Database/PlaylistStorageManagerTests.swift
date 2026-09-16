@testable import Boppa
import Dependencies
internal import Foundation
import SQLiteData
import Testing

struct PlaylistStorageManagerTests {
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

        func tracklistTrackRefs(playlist mediaId: String, source: String = "boppa.app") throws
            -> [StoredTracklistTrack]
        {
            try self.db.read { db in
                try StoredTracklistTrack
                    .where {
                        $0.tracklistMediaId.eq(mediaId).and($0.tracklistMediaSourceId.eq(source))
                    }
                    .order { $0.sortOrder }
                    .fetchAll(db)
            }
        }
    }

    // MARK: - Fixtures

    private func makeTrack(
        _ mediaId: String,
        source: String = "src",
        title: String = "Track Title"
    ) -> Track {
        Track(
            mediaId: mediaId,
            mediaSourceId: source,
            title: title
        )
    }

    // MARK: - addTrack / removeTrack

    @Test func addTrackCreatesPlaylistAndTracklistTrackRow() throws {
        let ctx = try Context()
        let t1 = self.makeTrack("t1")
        try ctx.withDatabase {
            try PlaylistStorageManager.shared.addTrackToPlaylist(t1, toPlaylist: "myplaylist")
        }

        let playlist = try #require(try ctx.tracklist("myplaylist", "boppa.app"))
        #expect(playlist.title == "myplaylist")
        #expect(playlist.tracklistType == Tracklist.TracklistType.playlist.rawValue)
        #expect(playlist.isSavedToLibrary == true)

        let refs = try ctx.tracklistTrackRefs(playlist: "myplaylist")
        #expect(refs.count == 1)
        #expect(refs.first?.trackMediaId == "t1")
    }

    @Test func addTrackTwiceIsIdempotentAndPreservesSortOrder() throws {
        let ctx = try Context()
        let t1 = self.makeTrack("t1")
        try ctx.withDatabase { try PlaylistStorageManager.shared.addTrackToPlaylist(
            t1,
            toPlaylist: "likes"
        ) }
        let firstRefs = try ctx.tracklistTrackRefs(playlist: "likes")

        try ctx.withDatabase { try PlaylistStorageManager.shared.addTrackToPlaylist(
            t1,
            toPlaylist: "likes"
        ) }
        let secondRefs = try ctx.tracklistTrackRefs(playlist: "likes")

        #expect(secondRefs.count == 1)
        #expect(secondRefs.first?.sortOrder == firstRefs.first?.sortOrder)
    }

    @Test func addingMultipleTracksAssignsIncreasingSortOrder() throws {
        let ctx = try Context()
        try ctx.withDatabase {
            try PlaylistStorageManager.shared.addTrackToPlaylist(
                self.makeTrack("t1"),
                toPlaylist: "likes"
            )
            try PlaylistStorageManager.shared.addTrackToPlaylist(
                self.makeTrack("t2"),
                toPlaylist: "likes"
            )
            try PlaylistStorageManager.shared.addTrackToPlaylist(
                self.makeTrack("t3"),
                toPlaylist: "likes"
            )
        }

        let refs = try ctx.tracklistTrackRefs(playlist: "likes")
        #expect(refs.map(\.trackMediaId) == ["t1", "t2", "t3"])
    }

    @Test func removeTrackDeletesRowAndOrphanedTrack() throws {
        let ctx = try Context()
        let t1 = self.makeTrack("t1")
        try ctx.withDatabase { try PlaylistStorageManager.shared.addTrackToPlaylist(
            t1,
            toPlaylist: "likes"
        ) }

        try ctx.withDatabase {
            try PlaylistStorageManager.shared.removeTrack(t1, fromPlaylist: "likes")
        }

        #expect(try ctx.tracklistTrackRefs(playlist: "likes").isEmpty)
        #expect(try ctx.track("t1") == nil)
    }

    @Test func removeTrackFromNonexistentPlaylistIsNoOp() throws {
        let ctx = try Context()
        let t1 = self.makeTrack("t1")

        try ctx.withDatabase {
            try PlaylistStorageManager.shared.removeTrack(t1, fromPlaylist: "ghost-playlist")
        }
    }

    @Test func removeTrackNotInPlaylistIsNoOp() throws {
        let ctx = try Context()

        try ctx.withDatabase {
            try PlaylistStorageManager.shared.addTrackToPlaylist(
                self.makeTrack("t1"),
                toPlaylist: "likes"
            )
            try PlaylistStorageManager.shared.removeTrack(
                self.makeTrack("t2"),
                fromPlaylist: "likes"
            )
        }

        #expect(try ctx.tracklistTrackRefs(playlist: "likes").count == 1)
    }

    @Test func areTracksInPlaylistIsScopedByMediaSourceId() throws {
        let ctx = try Context()
        let t1 = self.makeTrack("t1", source: "src-a")
        try ctx.withDatabase { try PlaylistStorageManager.shared.addTrackToPlaylist(
            t1,
            toPlaylist: "likes"
        ) }

        let sameIdDifferentSource = self.makeTrack("t1", source: "src-b")
        let memberPlaylistIds = try ctx.withDatabase {
            PlaylistStorageManager.shared.areTracksInPlaylist(
                sameIdDifferentSource,
                inPlaylists: ["likes"]
            )
        }

        #expect(memberPlaylistIds.isEmpty)
    }

    @Test func areTracksInPlaylistReturnsOnlyTheMatchingSubsetOfGivenPlaylists() throws {
        let ctx = try Context()
        let t1 = self.makeTrack("t1")
        let (playlistA, playlistC) = try ctx.withDatabase {
            let a = try PlaylistStorageManager.shared.createPlaylist(title: "A")
            _ = try PlaylistStorageManager.shared.createPlaylist(title: "B")
            let c = try PlaylistStorageManager.shared.createPlaylist(title: "C")
            return (a, c)
        }
        try ctx.withDatabase {
            try PlaylistStorageManager.shared.addTrackToPlaylist(t1, toPlaylist: "likes")
            try PlaylistStorageManager.shared.addTrackToPlaylist(t1, toPlaylist: playlistA.mediaId)
        }

        let memberPlaylistIds = try ctx.withDatabase {
            PlaylistStorageManager.shared.areTracksInPlaylist(
                t1,
                inPlaylists: [playlistA.mediaId, playlistC.mediaId, "likes", "ghost-playlist"]
            )
        }

        #expect(memberPlaylistIds == [playlistA.mediaId, "likes"])
    }

    @Test func likeAndUnlikeTrackRoundTrip() throws {
        let ctx = try Context()
        let t1 = self.makeTrack("t1")

        #expect(try ctx.withDatabase { PlaylistStorageManager.shared.isTrackLiked(t1) } == false)
        try ctx.withDatabase { try PlaylistStorageManager.shared.likeTrack(t1) }
        #expect(try ctx.withDatabase { PlaylistStorageManager.shared.isTrackLiked(t1) } == true)
        try ctx.withDatabase { try PlaylistStorageManager.shared.unlikeTrack(t1) }
        #expect(try ctx.withDatabase { PlaylistStorageManager.shared.isTrackLiked(t1) } == false)
    }

    @Test func trackInMultiplePlaylistsSurvivesRemovalFromOne() throws {
        let ctx = try Context()
        let t1 = self.makeTrack("t1")
        try ctx.withDatabase {
            try PlaylistStorageManager.shared.addTrackToPlaylist(t1, toPlaylist: "likes")
            try PlaylistStorageManager.shared.addTrackToPlaylist(t1, toPlaylist: "myplaylist")
        }

        try ctx.withDatabase {
            try PlaylistStorageManager.shared.removeTrack(t1, fromPlaylist: "likes")
        }

        #expect(try ctx.track("t1") != nil)
        #expect(
            try ctx.withDatabase {
                PlaylistStorageManager.shared.areTracksInPlaylist(t1, inPlaylists: ["myplaylist"])
            }.contains("myplaylist")
        )
    }

    @Test func findOrCreatePlaylistNamesLikesSpecially() throws {
        let ctx = try Context()
        try ctx.withDatabase {
            try PlaylistStorageManager.shared.addTrackToPlaylist(
                self.makeTrack("t1"),
                toPlaylist: "likes"
            )
            try PlaylistStorageManager.shared.addTrackToPlaylist(
                self.makeTrack("t2"),
                toPlaylist: "custom-id"
            )
        }

        let likes = try #require(try ctx.tracklist("likes", "boppa.app"))
        #expect(likes.title == "Likes")
        #expect(likes.tracklistType == Tracklist.TracklistType.likes.rawValue)
        let custom = try #require(try ctx.tracklist("custom-id", "boppa.app"))
        #expect(custom.title == "custom-id")
        #expect(custom.tracklistType == Tracklist.TracklistType.playlist.rawValue)
    }

    // MARK: - createPlaylist / fetchPlaylists

    @Test func createPlaylistInsertsEmptyPlaylistWithGeneratedId() throws {
        let ctx = try Context()
        let created = try ctx.withDatabase {
            try PlaylistStorageManager.shared.createPlaylist(title: "Road Trip")
        }

        #expect(created.title == "Road Trip")
        #expect(created.mediaSourceId == "boppa.app")
        #expect(created.tracklistType == Tracklist.TracklistType.playlist.rawValue)
        #expect(created.isSavedToLibrary == true)
        #expect(UUID(uuidString: created.mediaId) != nil)
        let stored = try #require(try ctx.tracklist(created.mediaId, "boppa.app"))
        #expect(stored.title == "Road Trip")
        #expect(try ctx.tracklistTrackRefs(playlist: created.mediaId).isEmpty)
    }

    @Test func createPlaylistTwiceAssignsDistinctIncreasingSortOrder() throws {
        let ctx = try Context()

        let first = try ctx
            .withDatabase { try PlaylistStorageManager.shared.createPlaylist(title: "First") }
        let second = try ctx
            .withDatabase { try PlaylistStorageManager.shared.createPlaylist(title: "Second") }

        #expect(first.mediaId != second.mediaId)
        #expect(first.sortOrder < second.sortOrder)
    }

    @Test func canAddTracksToACreatedPlaylist() throws {
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

        let refs = try ctx.tracklistTrackRefs(playlist: playlist.mediaId)
        #expect(refs.map(\.trackMediaId) == ["t1", "t2"])
    }

    @Test func fetchPlaylistsReturnsOnlyBoppaPlaylistsOrderedBySortOrder() throws {
        let ctx = try Context()
        try ctx.withDatabase {
            try PlaylistStorageManager.shared.createPlaylist(title: "First")
            try PlaylistStorageManager.shared.createPlaylist(title: "Second")
            try PlaylistStorageManager.shared.addTrackToPlaylist(
                self.makeTrack("t1"),
                toPlaylist: "likes"
            )
        }

        let playlists = try ctx.withDatabase { PlaylistStorageManager.shared.fetchPlaylists() }

        #expect(playlists.map(\.title) == ["First", "Second"])
    }

    // MARK: - moveTrack

    @Test func moveTrackAppliesNewOrderToBoppaPlaylist() throws {
        let ctx = try Context()
        let playlist = try ctx
            .withDatabase { try PlaylistStorageManager.shared.createPlaylist(title: "Mix") }
        let t1 = self.makeTrack("t1")
        let t2 = self.makeTrack("t2")
        let t3 = self.makeTrack("t3")
        try ctx.withDatabase {
            try PlaylistStorageManager.shared.addTrackToPlaylist(t1, toPlaylist: playlist.mediaId)
            try PlaylistStorageManager.shared.addTrackToPlaylist(t2, toPlaylist: playlist.mediaId)
            try PlaylistStorageManager.shared.addTrackToPlaylist(t3, toPlaylist: playlist.mediaId)
        }

        try ctx.withDatabase {
            try PlaylistStorageManager.shared.moveTrack(
                t3,
                after: nil,
                before: t1,
                inPlaylist: playlist.mediaId
            )
        }

        let refs = try ctx.tracklistTrackRefs(playlist: playlist.mediaId)
        #expect(refs.map(\.trackMediaId) == ["t3", "t1", "t2"])
    }

    @Test func moveTrackOnlyRewritesTheMovedTrack() throws {
        let ctx = try Context()
        let playlist = try ctx
            .withDatabase { try PlaylistStorageManager.shared.createPlaylist(title: "Mix") }
        let t1 = self.makeTrack("t1")
        let t2 = self.makeTrack("t2")
        let t3 = self.makeTrack("t3")
        try ctx.withDatabase {
            try PlaylistStorageManager.shared.addTrackToPlaylist(t1, toPlaylist: playlist.mediaId)
            try PlaylistStorageManager.shared.addTrackToPlaylist(t2, toPlaylist: playlist.mediaId)
            try PlaylistStorageManager.shared.addTrackToPlaylist(t3, toPlaylist: playlist.mediaId)
        }
        let before = try ctx.tracklistTrackRefs(playlist: playlist.mediaId)
        let t1KeyBefore = try #require(before.first { $0.trackMediaId == "t1" }).sortOrder
        let t2KeyBefore = try #require(before.first { $0.trackMediaId == "t2" }).sortOrder

        try ctx.withDatabase {
            try PlaylistStorageManager.shared.moveTrack(
                t3,
                after: nil,
                before: t1,
                inPlaylist: playlist.mediaId
            )
        }

        let after = try ctx.tracklistTrackRefs(playlist: playlist.mediaId)
        #expect(try #require(after.first { $0.trackMediaId == "t1" }).sortOrder == t1KeyBefore)
        #expect(try #require(after.first { $0.trackMediaId == "t2" }).sortOrder == t2KeyBefore)
    }

    @Test func moveTrackIsNoOpForNonexistentPlaylist() throws {
        let ctx = try Context()
        let t1 = self.makeTrack("t1")

        try ctx.withDatabase {
            try PlaylistStorageManager.shared.moveTrack(
                t1,
                after: nil,
                before: nil,
                inPlaylist: "ghost-playlist"
            )
        }
    }

    @Test func moveTrackIsNoOpForLikes() throws {
        let ctx = try Context()
        let t1 = self.makeTrack("t1")
        let t2 = self.makeTrack("t2")
        try ctx.withDatabase {
            try PlaylistStorageManager.shared.addTrackToPlaylist(t1, toPlaylist: "likes")
            try PlaylistStorageManager.shared.addTrackToPlaylist(t2, toPlaylist: "likes")
        }
        let before = try ctx.tracklistTrackRefs(playlist: "likes")

        try ctx.withDatabase {
            try PlaylistStorageManager.shared.moveTrack(
                t2,
                after: nil,
                before: t1,
                inPlaylist: "likes"
            )
        }

        let after = try ctx.tracklistTrackRefs(playlist: "likes")
        #expect(after.map(\.sortOrder) == before.map(\.sortOrder))
    }

    @Test func moveTrackPostsPlaylistMembershipChangedNotification() throws {
        let ctx = try Context()
        let playlist = try ctx
            .withDatabase { try PlaylistStorageManager.shared.createPlaylist(title: "Mix") }
        let t1 = self.makeTrack("t1")
        let t2 = self.makeTrack("t2")
        try ctx.withDatabase {
            try PlaylistStorageManager.shared.addTrackToPlaylist(t1, toPlaylist: playlist.mediaId)
            try PlaylistStorageManager.shared.addTrackToPlaylist(t2, toPlaylist: playlist.mediaId)
        }
        var received = false
        let observer = NotificationCenter.default.addObserver(
            forName: .playlistMembershipChanged, object: nil, queue: nil
        ) { _ in received = true }
        defer { NotificationCenter.default.removeObserver(observer) }

        try ctx.withDatabase {
            try PlaylistStorageManager.shared.moveTrack(
                t2,
                after: nil,
                before: t1,
                inPlaylist: playlist.mediaId
            )
        }

        #expect(received)
    }

    @Test func moveTrackDoesNotPostNotificationForNonexistentPlaylist() throws {
        let ctx = try Context()
        let t1 = self.makeTrack("t1")
        var received = false
        let observer = NotificationCenter.default.addObserver(
            forName: .playlistMembershipChanged, object: nil, queue: nil
        ) { _ in received = true }
        defer { NotificationCenter.default.removeObserver(observer) }

        try ctx.withDatabase {
            try PlaylistStorageManager.shared.moveTrack(
                t1,
                after: nil,
                before: nil,
                inPlaylist: "ghost-playlist"
            )
        }

        #expect(!received)
    }
}
