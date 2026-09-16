import Dependencies
import Foundation
import os
import SQLiteData

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "Boppa", category: "PlaylistStorageManager"
)

/// Storage for boppa.app playlists (including the "likes" playlist) - in-app tracklists the
/// user creates and manages directly, as opposed to tracklists sourced from a media source.
class PlaylistStorageManager {
    static let shared = PlaylistStorageManager()

    @Dependency(\.defaultDatabase) var database

    private init() {}

    // MARK: - DB Access

    private func withReadDB<T>(_ db: Database?, _ body: (Database) throws -> T) throws -> T {
        if let db { return try body(db) }
        return try self.database.read(body)
    }

    private func withWriteDB<T>(_ db: Database?, _ body: (Database) throws -> T) throws -> T {
        if let db { return try body(db) }
        return try self.database.write(body)
    }

    // MARK: - Reads

    func fetchPlaylists(db: Database? = nil) -> [StoredTracklist] {
        (try? self.withReadDB(db) { db in
            try StoredTracklist
                .where {
                    $0.mediaSourceId.eq("boppa.app")
                        .and($0.tracklistType.eq(Tracklist.TracklistType.playlist.rawValue))
                }
                .order { $0.sortOrder }
                .fetchAll(db)
        }) ?? []
    }

    func areTracksInPlaylist(
        _ track: Track,
        inPlaylists playlistIds: [String],
        db: Database? = nil
    ) -> Set<String> {
        guard !playlistIds.isEmpty else { return [] }
        return (try? self.withReadDB(db) { db in
            try StoredTracklistTrack
                .where {
                    $0.tracklistMediaId.in(playlistIds)
                        .and($0.tracklistMediaSourceId.eq("boppa.app"))
                        .and($0.trackMediaId.eq(track.mediaId))
                        .and($0.trackMediaSourceId.eq(track.mediaSourceId))
                }
                .fetchAll(db)
        })?.reduce(into: Set<String>()) { $0.insert($1.tracklistMediaId) } ?? []
    }

    func isTrackLiked(_ track: Track, db: Database? = nil) -> Bool {
        self.areTracksInPlaylist(track, inPlaylists: ["likes"], db: db).contains("likes")
    }

    // MARK: - Writes

    @discardableResult
    func createPlaylist(title: String, db: Database? = nil) throws -> StoredTracklist {
        let stored = try self.withWriteDB(db) { db in
            try self.createPlaylistStub(
                mediaId: UUID().uuidString,
                title: title,
                tracklistType: .playlist,
                db: db
            )
        }
        logger.info("Created playlist '\(title)'")
        return stored
    }

    func addTrackToPlaylist(
        _ track: Track,
        toPlaylist playlistId: String,
        db: Database? = nil
    ) throws {
        try self.withWriteDB(db) { db in
            let tracklist = try self.findOrCreatePlaylist(playlistId: playlistId, db: db)
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

    func removeTrack(_ track: Track, fromPlaylist playlistId: String, db: Database? = nil) throws {
        try self.withWriteDB(db) { db in
            let tracklist =
                try StoredTracklist
                    .where { $0.mediaId.eq(playlistId).and($0.mediaSourceId.eq("boppa.app")) }
                    .fetchOne(db)
            guard let tracklist else { return }
            try self.removeTrack(track, from: tracklist, db: db)
        }
    }

    func likeTrack(_ track: Track, db: Database? = nil) throws {
        try self.addTrackToPlaylist(track, toPlaylist: "likes", db: db)
    }

    func unlikeTrack(_ track: Track, db: Database? = nil) throws {
        try self.removeTrack(track, fromPlaylist: "likes", db: db)
    }

    func moveTrack(
        _ track: Track,
        after previousTrack: Track?,
        before nextTrack: Track?,
        inPlaylist playlistId: String,
        db: Database? = nil
    ) throws {
        var didReorder = false
        try self.withWriteDB(db) { db in
            let tracklist = try StoredTracklist
                .where {
                    $0.mediaId.eq(playlistId)
                        .and($0.mediaSourceId.eq("boppa.app"))
                        .and($0.tracklistType.eq(Tracklist.TracklistType.playlist.rawValue))
                }
                .fetchOne(db)
            guard let tracklist else { return }
            didReorder = true

            func sortOrderKey(for track: Track?) throws -> String? {
                guard let track else { return nil }
                let storedTrack = try StoredTrack
                    .where {
                        $0.mediaId.eq(track.mediaId).and($0.mediaSourceId.eq(track.mediaSourceId))
                    }
                    .fetchOne(db)
                guard let storedTrack else { return nil }
                return try FractionalIndexKeyQueries.shared.trackSortOrder(
                    tracklist: tracklist,
                    track: storedTrack,
                    db: db
                )
            }

            let prevKey = try sortOrderKey(for: previousTrack)
            let nextKey = try sortOrderKey(for: nextTrack)
            let newKey = FractionalIndex.generateKeyBetween(prevKey, nextKey)

            try StoredTracklistTrack.update { $0.sortOrder = newKey }
                .where {
                    $0.tracklistMediaId.eq(playlistId)
                        .and($0.tracklistMediaSourceId.eq("boppa.app"))
                        .and($0.trackMediaId.eq(track.mediaId))
                        .and($0.trackMediaSourceId.eq(track.mediaSourceId))
                }
                .execute(db)
        }
        if didReorder {
            NotificationCenter.default.post(name: .playlistMembershipChanged, object: nil)
        }
    }

    private func addTrack(_ track: Track, to tracklist: StoredTracklist, db: Database) throws {
        try TrackStorageManager.shared.upsertTracks([track], db: db)
        try TrackStorageManager.shared.markSavedToLibrary([track], db: db)
        let maxKey = try FractionalIndexKeyQueries.shared.maxTrackSortOrder(
            tracklist: tracklist,
            db: db
        )
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
        _ track: Track, from tracklist: StoredTracklist, db: Database
    ) throws {
        try StoredTracklistTrack
            .where {
                $0.tracklistMediaId.eq(tracklist.mediaId)
                    .and($0.tracklistMediaSourceId.eq(tracklist.mediaSourceId))
                    .and($0.trackMediaId.eq(track.mediaId))
                    .and($0.trackMediaSourceId.eq(track.mediaSourceId))
            }
            .delete()
            .execute(db)
        try TrackStorageManager.shared.deleteTrackStubsIfOrphaned([track], db: db)
    }

    // MARK: - Playlist Stubs

    @discardableResult
    func createPlaylistStub(
        mediaId: String,
        title: String,
        tracklistType: Tracklist.TracklistType,
        db: Database? = nil
    ) throws -> StoredTracklist {
        try self.withWriteDB(db) { db in
            let typeString = tracklistType.rawValue
            let maxKey = try FractionalIndexKeyQueries.shared.maxTracklistSortOrder(
                type: typeString,
                db: db
            )
            let newSortOrder = FractionalIndex.generateKeyBetween(maxKey, nil)
            try StoredTracklist.insert {
                StoredTracklist.Draft(
                    mediaId: mediaId,
                    mediaSourceId: "boppa.app",
                    title: title,
                    subtitle: nil,
                    lowResArtworkUrl: nil,
                    highResArtworkUrl: nil,
                    tracklistType: typeString,
                    isPinned: false,
                    isSavedToLibrary: true,
                    sortOrder: newSortOrder
                )
            }.execute(db)
            return StoredTracklist(
                mediaId: mediaId,
                mediaSourceId: "boppa.app",
                title: title,
                subtitle: nil,
                year: nil,
                lowResArtworkUrl: nil,
                highResArtworkUrl: nil,
                url: nil,
                tracklistType: typeString,
                isPinned: false,
                isSavedToLibrary: true,
                sortOrder: newSortOrder
            )
        }
    }

    func findOrCreatePlaylist(playlistId: String, db: Database? = nil) throws -> StoredTracklist {
        try self.withWriteDB(db) { db in
            let existing =
                try StoredTracklist
                    .where { $0.mediaId.eq(playlistId).and($0.mediaSourceId.eq("boppa.app")) }
                    .fetchOne(db)
            if let existing { return existing }
            let tracklistType: Tracklist.TracklistType = playlistId == "likes" ? .likes : .playlist
            let title = playlistId == "likes" ? "Likes" : playlistId
            return try self.createPlaylistStub(
                mediaId: playlistId,
                title: title,
                tracklistType: tracklistType,
                db: db
            )
        }
    }
}
