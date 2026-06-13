import Dependencies
import Foundation
import os
import SQLiteData

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Boppa", category: "TrackStorageManager")

class TrackStorageManager {
    static let shared = TrackStorageManager()

    @Dependency(\.defaultDatabase) var database

    private init() {}

    // MARK: - Reads

    func fetchLibraryTracks() -> [StoredTrack] {
        (try? self.database.read { db in
            try StoredTrack.fetchAll(db)
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
            let alreadyPresent = try StoredTracklistTrack
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
            let tracklist = try StoredTracklist
                .where { $0.mediaId.eq(playlistId).and($0.mediaSourceId.eq("boppa.app")) }
                .fetchOne(db)
            guard let tracklist else { return }
            try self.removeTrack(mediaId: track.mediaId, mediaSourceId: track.mediaSourceId, from: tracklist, db: db)
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

    func deleteIfOrphaned(mediaId: String, mediaSourceId: String, db: Database) throws {
        let remaining = try StoredTracklistTrack
            .where { $0.trackMediaId.eq(mediaId).and($0.trackMediaSourceId.eq(mediaSourceId)) }
            .fetchAll(db).count
        guard remaining == 0 else { return }

        let artistRefs = try StoredTrackArtist
            .where { $0.trackMediaId.eq(mediaId).and($0.trackMediaSourceId.eq(mediaSourceId)) }
            .fetchAll(db)
        let albumRefs = try StoredTrackAlbum
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

    // MARK: Private

    private func deleteArtistIfOrphaned(_ ref: StoredTrackArtist, db: Database) throws {
        let inTracks = try StoredTrackArtist
            .where { $0.artistMediaId.eq(ref.artistMediaId).and($0.artistMediaSourceId.eq(ref.artistMediaSourceId)) }
            .fetchAll(db).count
        let inTracklists = try StoredTracklistArtist
            .where { $0.artistMediaId.eq(ref.artistMediaId).and($0.artistMediaSourceId.eq(ref.artistMediaSourceId)) }
            .fetchAll(db).count
        guard inTracks == 0, inTracklists == 0 else { return }
        try StoredArtist
            .where { $0.mediaId.eq(ref.artistMediaId).and($0.mediaSourceId.eq(ref.artistMediaSourceId)) }
            .delete()
            .execute(db)
        logger.info("Deleted orphaned artist '\(ref.artistMediaId)'")
    }

    private func deleteAlbumStubIfOrphaned(_ ref: StoredTrackAlbum, db: Database) throws {
        let trackCount = try StoredTrackAlbum
            .where { $0.tracklistMediaId.eq(ref.tracklistMediaId).and($0.tracklistMediaSourceId.eq(ref.tracklistMediaSourceId)) }
            .fetchAll(db).count
        guard trackCount == 0 else { return }
        let album = try StoredTracklist
            .where { $0.mediaId.eq(ref.tracklistMediaId).and($0.mediaSourceId.eq(ref.tracklistMediaSourceId)) }
            .fetchOne(db)
        guard let album, !album.isSavedToLibrary else { return }
        try StoredTracklist
            .where { $0.mediaId.eq(ref.tracklistMediaId).and($0.mediaSourceId.eq(ref.tracklistMediaSourceId)) }
            .delete()
            .execute(db)
        logger.info("Deleted orphaned album stub '\(ref.tracklistMediaId)'")
    }

    private func addTrack(_ track: Track, to tracklist: StoredTracklist, db: Database) throws {
        try TracklistStorageManager.shared.upsertTrack(track, db: db)
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

    private func removeTrack(mediaId: String, mediaSourceId: String, from tracklist: StoredTracklist, db: Database) throws {
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

    private func findOrCreatePlaylist(playlistId: String, db: Database) throws -> StoredTracklist {
        let existing = try StoredTracklist
            .where { $0.mediaId.eq(playlistId).and($0.mediaSourceId.eq("boppa.app")) }
            .fetchOne(db)
        if let existing { return existing }
        let tracklistType = playlistId == "likes"
            ? Tracklist.TracklistType.likes.rawValue
            : Tracklist.TracklistType.playlist.rawValue
        let title = playlistId == "likes" ? "Likes" : playlistId
        try StoredTracklist.insert {
            StoredTracklist.Draft(
                mediaId: playlistId,
                mediaSourceId: "boppa.app",
                title: title,
                subtitle: nil,
                artworkUrl: nil,
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
