import Dependencies
import Foundation
import os
import SQLiteData

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "Boppa", category: "TrackStorageManager"
)

class TrackStorageManager {
    static let shared = TrackStorageManager()

    @Dependency(\.defaultDatabase) var database

    private init() {}

    // MARK: - Reads

    func fetchLibraryTracks() -> [StoredTrack] {
        (try? self.database.read { db in
            try StoredTrack.where(\.isSavedToLibrary).fetchAll(db)
        }) ?? []
    }

    // MARK: - Boppa Playlist Management

    func isTrack(_ track: Track, inPlaylist playlistId: String) -> Bool {
        (try? self.database.read { db in
            try StoredTracklistTrack
                .where {
                    $0.tracklistMediaId.eq(playlistId)
                        .and($0.tracklistMediaSourceId.eq("boppa.app"))
                        .and($0.trackMediaId.eq(track.mediaId))
                        .and($0.trackMediaSourceId.eq(track.mediaSourceId))
                }
                .fetchOne(db) != nil
        }) ?? false
    }

    func addTrack(_ track: Track, toPlaylist playlistId: String) throws {
        try self.database.write { db in
            let tracklist = try findOrCreatePlaylist(playlistId: playlistId, db: db)
            let alreadyPresent =
                try StoredTracklistTrack
                    .where {
                        $0.tracklistMediaId.eq(tracklist.mediaId)
                            .and($0.tracklistMediaSourceId.eq(tracklist.mediaSourceId))
                            .and($0.trackMediaId.eq(track.mediaId))
                            .and($0.trackMediaSourceId.eq(track.mediaSourceId))
                    }
                    .fetchOne(db) != nil
            guard !alreadyPresent else { return }
            try self.addTrack(track, to: tracklist, db: db)
        }
    }

    func removeTrack(_ track: Track, fromPlaylist playlistId: String) throws {
        try self.database.write { db in
            let tracklist =
                try StoredTracklist
                    .where { $0.mediaId.eq(playlistId).and($0.mediaSourceId.eq("boppa.app")) }
                    .fetchOne(db)
            guard let tracklist else { return }
            try self.removeTrack(
                mediaId: track.mediaId, mediaSourceId: track.mediaSourceId, from: tracklist, db: db
            )
        }
    }

    func isTrackLiked(_ track: Track) -> Bool {
        self.isTrack(track, inPlaylist: "likes")
    }

    func likeTrack(_ track: Track) throws {
        try self.addTrack(track, toPlaylist: "likes")
    }

    func unlikeTrack(_ track: Track) throws {
        try self.removeTrack(track, fromPlaylist: "likes")
    }

    // MARK: Orphan Cleanup

    // Deletes a track once it has no remaining tracklist joins, unless it's isRecent,
    // in which case it survives but has isSavedToLibrary set to false.
    func deleteIfOrphaned(mediaId: String, mediaSourceId: String, db: Database) throws {

        // If track is still present in tracklist, exit
        let remaining =
            try StoredTracklistTrack
                .where { $0.trackMediaId.eq(mediaId).and($0.trackMediaSourceId.eq(mediaSourceId)) }
                .fetchCount(db)
        guard remaining == 0 else { return }

        // If track does not exist in DB, exit
        let track =
            try StoredTrack
                .where { $0.mediaId.eq(mediaId).and($0.mediaSourceId.eq(mediaSourceId)) }
                .fetchOne(db)
        guard let track else { return }

        // If track is recent only set isSavedToLibrary to false, exit
        if track.isRecent {
            if track.isSavedToLibrary {
                try StoredTrack.update { $0.isSavedToLibrary = false }
                    .where { $0.mediaId.eq(mediaId).and($0.mediaSourceId.eq(mediaSourceId)) }
                    .execute(db)
            }
            return
        }

        let artistRefs =
            try StoredTrackArtist
                .where { $0.trackMediaId.eq(mediaId).and($0.trackMediaSourceId.eq(mediaSourceId)) }
                .fetchAll(db)
        let albumRefs =
            try StoredTrackAlbum
                .where { $0.trackMediaId.eq(mediaId).and($0.trackMediaSourceId.eq(mediaSourceId)) }
                .fetchAll(db)

        try StoredTrack
            .where { $0.mediaId.eq(mediaId).and($0.mediaSourceId.eq(mediaSourceId)) }
            .delete()
            .execute(db)
        logger.info("Deleted orphaned track '\(mediaId)' from '\(mediaSourceId)'")

        for ref in artistRefs {
            try self.deleteArtistIfOrphaned(ref, db: db)
        }
        for ref in albumRefs {
            try self.deleteAlbumStubIfOrphaned(ref, db: db)
        }
    }

    // MARK: - Recents

    func markRecentlyPlayed(_ track: Track, playedAt: Double, db: Database) throws {
        try self.upsertTrack(track, db: db)
        try StoredTrack.update {
            $0.isRecent = true
            $0.lastPlayedTimestamp = #bind(playedAt)
        }
        .where { $0.mediaId.eq(track.mediaId).and($0.mediaSourceId.eq(track.mediaSourceId)) }
        .execute(db)
    }

    func unmarkRecentlyPlayed(mediaId: String, mediaSourceId: String, db: Database) throws {
        try StoredTrack.update { $0.isRecent = false }
            .where { $0.mediaId.eq(mediaId).and($0.mediaSourceId.eq(mediaSourceId)) }
            .execute(db)
        try self.deleteIfOrphaned(mediaId: mediaId, mediaSourceId: mediaSourceId, db: db)
    }

    func markArtistRecentlyViewed(_ artist: Artist, viewedAt: Double, db: Database) throws {
        try self.upsertArtist(artist, db: db)
        try StoredArtist.update {
            $0.isRecent = true
            $0.lastViewedTimestamp = #bind(viewedAt)
        }
        .where { $0.mediaId.eq(artist.mediaId).and($0.mediaSourceId.eq(artist.mediaSourceId)) }
        .execute(db)
    }

    func unmarkArtistRecentlyViewed(mediaId: String, mediaSourceId: String, db: Database) throws {
        try StoredArtist.update { $0.isRecent = false }
            .where { $0.mediaId.eq(mediaId).and($0.mediaSourceId.eq(mediaSourceId)) }
            .execute(db)
        try self.deleteArtistIfOrphaned(mediaId: mediaId, mediaSourceId: mediaSourceId, db: db)
    }

    func unmarkTracklistRecentlyViewed(mediaId: String, mediaSourceId: String, db: Database) throws {
        try StoredTracklist.update { $0.isRecent = false }
            .where { $0.mediaId.eq(mediaId).and($0.mediaSourceId.eq(mediaSourceId)) }
            .execute(db)
        try self.deleteAlbumStubIfOrphaned(mediaId: mediaId, mediaSourceId: mediaSourceId, db: db)
    }

    // MARK: Private

    private func deleteArtistIfOrphaned(_ ref: StoredTrackArtist, db: Database) throws {
        try self.deleteArtistIfOrphaned(
            mediaId: ref.artistMediaId, mediaSourceId: ref.artistMediaSourceId, db: db
        )
    }

    private func deleteArtistIfOrphaned(mediaId: String, mediaSourceId: String, db: Database) throws {
        let inTracks =
            try StoredTrackArtist
                .where { $0.artistMediaId.eq(mediaId).and($0.artistMediaSourceId.eq(mediaSourceId)) }
                .fetchCount(db)
        guard inTracks == 0 else { return }
        let artist =
            try StoredArtist
                .where { $0.mediaId.eq(mediaId).and($0.mediaSourceId.eq(mediaSourceId)) }
                .fetchOne(db)
        guard let artist, !artist.isRecent else { return }
        try StoredArtist
            .where { $0.mediaId.eq(mediaId).and($0.mediaSourceId.eq(mediaSourceId)) }
            .delete()
            .execute(db)
        logger.info("Deleted orphaned artist '\(mediaId)'")
    }

    private func deleteAlbumStubIfOrphaned(_ ref: StoredTrackAlbum, db: Database) throws {
        try self.deleteAlbumStubIfOrphaned(
            mediaId: ref.tracklistMediaId, mediaSourceId: ref.tracklistMediaSourceId, db: db
        )
    }

    private func deleteAlbumStubIfOrphaned(mediaId: String, mediaSourceId: String, db: Database)
        throws
    {
        let trackCount =
            try StoredTrackAlbum
                .where {
                    $0.tracklistMediaId.eq(mediaId).and($0.tracklistMediaSourceId.eq(mediaSourceId))
                }
                .fetchCount(db)
        guard trackCount == 0 else { return }
        let album =
            try StoredTracklist
                .where { $0.mediaId.eq(mediaId).and($0.mediaSourceId.eq(mediaSourceId)) }
                .fetchOne(db)
        guard let album, !album.isSavedToLibrary, !album.isRecent else { return }
        try StoredTracklist
            .where { $0.mediaId.eq(mediaId).and($0.mediaSourceId.eq(mediaSourceId)) }
            .delete()
            .execute(db)
        logger.info("Deleted orphaned album stub '\(mediaId)'")
    }

    private func addTrack(_ track: Track, to tracklist: StoredTracklist, db: Database) throws {
        try self.upsertTrack(track, db: db)
        try self.markSavedToLibrary(mediaId: track.mediaId, mediaSourceId: track.mediaSourceId, db: db)
        let maxKey = try StoredTracklistTrack
            .where {
                $0.tracklistMediaId.eq(tracklist.mediaId)
                    .and($0.tracklistMediaSourceId.eq(tracklist.mediaSourceId))
            }
            .order { $0.sortOrder.desc() }
            .fetchOne(db)?
            .sortOrder
        let newKey = FractionalIndex.generateKeyBetween(maxKey, nil)
        try StoredTracklistTrack.insert {
            StoredTracklistTrack.Draft(
                tracklistMediaId: tracklist.mediaId,
                tracklistMediaSourceId: tracklist.mediaSourceId,
                trackMediaId: track.mediaId,
                trackMediaSourceId: track.mediaSourceId,
                sortOrder: newKey
            )
        }.execute(db)
    }

    private func removeTrack(
        mediaId: String, mediaSourceId: String, from tracklist: StoredTracklist, db: Database
    ) throws {
        try StoredTracklistTrack
            .where {
                $0.tracklistMediaId.eq(tracklist.mediaId)
                    .and($0.tracklistMediaSourceId.eq(tracklist.mediaSourceId))
                    .and($0.trackMediaId.eq(mediaId))
                    .and($0.trackMediaSourceId.eq(mediaSourceId))
            }
            .delete()
            .execute(db)
        try self.deleteIfOrphaned(mediaId: mediaId, mediaSourceId: mediaSourceId, db: db)
    }

    // MARK: - Track Reads

    func loadArtistsForTrack(_ track: StoredTrack, db: Database) throws -> [Artist] {
        try self.loadStoredArtistsForTrack(track, db: db).map { $0.toArtist() }
    }

    func loadStoredArtistsForTrack(_ track: StoredTrack, db: Database) throws -> [StoredArtist] {
        try StoredTrackArtist
            .where {
                $0.trackMediaId.eq(track.mediaId).and($0.trackMediaSourceId.eq(track.mediaSourceId))
            }
            .join(StoredArtist.all) { ta, a in
                ta.artistMediaId.eq(a.mediaId).and(ta.artistMediaSourceId.eq(a.mediaSourceId))
            }
            .order { ta, _ in ta.sortOrder }
            .select { _, a in a }
            .fetchAll(db)
    }

    func loadAlbumsForTrack(_ track: StoredTrack, db: Database) throws -> [Tracklist] {
        try self.loadStoredAlbumsForTrack(track, db: db).map { Tracklist(storedTracklist: $0) }
    }

    func loadStoredAlbumsForTrack(_ track: StoredTrack, db: Database) throws -> [StoredTracklist] {
        try StoredTrackAlbum
            .where {
                $0.trackMediaId.eq(track.mediaId).and($0.trackMediaSourceId.eq(track.mediaSourceId))
            }
            .join(StoredTracklist.all) { ta, tl in
                ta.tracklistMediaId.eq(tl.mediaId).and(
                    ta.tracklistMediaSourceId.eq(tl.mediaSourceId)
                )
            }
            .order { ta, _ in ta.sortOrder }
            .select { _, tl in tl }
            .fetchAll(db)
    }

    // MARK: - Track Writes

    func upsertTrack(_ track: Track, db: Database) throws {
        let existing =
            try StoredTrack
                .where { $0.mediaId.eq(track.mediaId).and($0.mediaSourceId.eq(track.mediaSourceId)) }
                .fetchOne(db)
        if let existing {
            let existingArtists = try loadStoredArtistsForTrack(existing, db: db)
            let existingAlbums = try loadStoredAlbumsForTrack(existing, db: db)
            if !existing.contentMatches(track, artists: existingArtists, albums: existingAlbums) {
                try self.updateTrackScalars(track, stored: existing, db: db)
                try self.replaceTrackArtists(track: existing, artists: track.artists, db: db)
                try self.replaceTrackAlbums(track: existing, albums: track.albums, db: db)
            }
        } else {
            try StoredTrack.insert {
                StoredTrack.Draft(
                    mediaId: track.mediaId,
                    mediaSourceId: track.mediaSourceId,
                    title: track.title,
                    subtitle: track.subtitle,
                    duration: track.duration,
                    lowResArtworkUrl: track.lowResArtworkUrl,
                    highResArtworkUrl: track.highResArtworkUrl,
                    url: track.url,
                    type: track.type.rawValue,
                    metadata: track.metadata
                )
            }.execute(db)
            let inserted = StoredTrack(
                mediaId: track.mediaId,
                mediaSourceId: track.mediaSourceId,
                title: track.title,
                subtitle: track.subtitle,
                duration: track.duration,
                lowResArtworkUrl: track.lowResArtworkUrl,
                highResArtworkUrl: track.highResArtworkUrl,
                url: track.url,
                type: track.type.rawValue,
                metadata: track.metadata
            )
            try self.replaceTrackArtists(track: inserted, artists: track.artists, db: db)
            try self.replaceTrackAlbums(track: inserted, albums: track.albums, db: db)
        }
    }

    func markSavedToLibrary(mediaId: String, mediaSourceId: String, db: Database) throws {
        try StoredTrack.update { $0.isSavedToLibrary = true }
            .where { $0.mediaId.eq(mediaId).and($0.mediaSourceId.eq(mediaSourceId)) }
            .execute(db)
    }

    func updateTrackScalars(_ track: Track, stored: StoredTrack, db: Database) throws {
        try StoredTrack.update {
            $0.title = track.title
            $0.subtitle = track.subtitle
            $0.duration = track.duration
            $0.lowResArtworkUrl = track.lowResArtworkUrl
            $0.highResArtworkUrl = track.highResArtworkUrl
            $0.type = track.type.rawValue
            $0.metadata = track.metadata
        }
        .where { $0.mediaId.eq(stored.mediaId).and($0.mediaSourceId.eq(stored.mediaSourceId)) }
        .execute(db)
    }

    func replaceTrackArtists(track: StoredTrack, artists: [Artist], db: Database) throws {
        let oldRefs =
            try StoredTrackArtist
                .where {
                    $0.trackMediaId.eq(track.mediaId).and($0.trackMediaSourceId.eq(track.mediaSourceId))
                }
                .fetchAll(db)
        try StoredTrackArtist
            .where {
                $0.trackMediaId.eq(track.mediaId).and($0.trackMediaSourceId.eq(track.mediaSourceId))
            }
            .delete()
            .execute(db)
        let keys = FractionalIndex.generateNKeysBetween(nil, nil, n: artists.count)
        for (artist, key) in zip(artists, keys) {
            try self.upsertArtist(artist, db: db)
            try StoredTrackArtist.insert {
                StoredTrackArtist.Draft(
                    trackMediaId: track.mediaId,
                    trackMediaSourceId: track.mediaSourceId,
                    artistMediaId: artist.mediaId,
                    artistMediaSourceId: artist.mediaSourceId,
                    sortOrder: key
                )
            }.execute(db)
        }
        for ref in oldRefs {
            try self.deleteArtistIfOrphaned(ref, db: db)
        }
    }

    func replaceTrackAlbums(track: StoredTrack, albums: [Tracklist], db: Database) throws {
        let oldRefs =
            try StoredTrackAlbum
                .where {
                    $0.trackMediaId.eq(track.mediaId).and($0.trackMediaSourceId.eq(track.mediaSourceId))
                }
                .fetchAll(db)
        try StoredTrackAlbum
            .where {
                $0.trackMediaId.eq(track.mediaId).and($0.trackMediaSourceId.eq(track.mediaSourceId))
            }
            .delete()
            .execute(db)
        let keys = FractionalIndex.generateNKeysBetween(nil, nil, n: albums.count)
        for (album, key) in zip(albums, keys) {
            try TracklistStorageManager.shared.upsertTracklistStub(album, db: db)
            try StoredTrackAlbum.insert {
                StoredTrackAlbum.Draft(
                    trackMediaId: track.mediaId,
                    trackMediaSourceId: track.mediaSourceId,
                    tracklistMediaId: album.mediaId,
                    tracklistMediaSourceId: album.mediaSourceId,
                    sortOrder: key
                )
            }.execute(db)
        }
        for ref in oldRefs {
            try self.deleteAlbumStubIfOrphaned(ref, db: db)
        }
    }

    @discardableResult
    private func upsertArtist(_ artist: Artist, db: Database) throws -> String {
        let existing =
            try StoredArtist
                .where { $0.mediaId.eq(artist.mediaId).and($0.mediaSourceId.eq(artist.mediaSourceId)) }
                .fetchOne(db)
        if let existing {
            try StoredArtist.update {
                if !artist.name.isEmpty { $0.name = artist.name }
                if artist.lowResArtworkUrl != nil { $0.lowResArtworkUrl = artist.lowResArtworkUrl }
                if artist.highResArtworkUrl != nil { $0.highResArtworkUrl = artist.highResArtworkUrl }
                if artist.url != nil { $0.url = artist.url }
            }
            .where {
                $0.mediaId.eq(existing.mediaId).and($0.mediaSourceId.eq(existing.mediaSourceId))
            }
            .execute(db)
        } else {
            try StoredArtist.insert {
                StoredArtist.Draft(
                    mediaId: artist.mediaId,
                    mediaSourceId: artist.mediaSourceId,
                    name: artist.name,
                    lowResArtworkUrl: artist.lowResArtworkUrl,
                    highResArtworkUrl: artist.highResArtworkUrl,
                    url: artist.url
                )
            }.execute(db)
        }
        return artist.mediaId
    }

    // MARK: - Private

    private func findOrCreatePlaylist(playlistId: String, db: Database) throws -> StoredTracklist {
        let existing =
            try StoredTracklist
                .where { $0.mediaId.eq(playlistId).and($0.mediaSourceId.eq("boppa.app")) }
                .fetchOne(db)
        if let existing { return existing }
        let tracklistType =
            playlistId == "likes"
                ? Tracklist.TracklistType.likes.rawValue
                : Tracklist.TracklistType.playlist.rawValue
        let title = playlistId == "likes" ? "Likes" : playlistId
        // TODO: sortOrder is hardcoded to "a0" here since only "likes" exists today. Once
        // users can create their own Boppa-managed playlists, compute a real key past the
        // current max (the way TracklistStorageManager.upsertTracklistStub does for albums)
        // so multiple playlists don't collide on the same sortOrder.
        try StoredTracklist.insert {
            StoredTracklist.Draft(
                mediaId: playlistId,
                mediaSourceId: "boppa.app",
                title: title,
                subtitle: nil,
                lowResArtworkUrl: nil,
                highResArtworkUrl: nil,
                tracklistType: tracklistType,
                isPinned: false,
                isSavedToLibrary: true,
                sortOrder: "a0"
            )
        }.execute(db)
        return try StoredTracklist
            .where { $0.mediaId.eq(playlistId).and($0.mediaSourceId.eq("boppa.app")) }
            .fetchOne(db)!
    }
}
