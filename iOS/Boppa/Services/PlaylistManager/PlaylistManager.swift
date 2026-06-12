import Dependencies
import Foundation
import os
import SQLiteData

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Boppa", category: "PlaylistManager")

extension Notification.Name {
    static let playlistMembershipChanged = Notification.Name("playlistMembershipChanged")
}

@Observable
@MainActor
class PlaylistManager {
    static let shared = PlaylistManager()

    @ObservationIgnored
    @Dependency(\.defaultDatabase) var database

    /// Incremented on every add/remove so @Observable views re-evaluate isInPlaylist.
    private(set) var membershipVersion: Int = 0

    private init() {}

    func isInPlaylist(_ track: Track, playlistId: String) -> Bool {
        _ = self.membershipVersion
        return (try? self.database.read { db in
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

    func addToPlaylist(_ track: Track, playlistId: String) {
        guard !self.isInPlaylist(track, playlistId: playlistId) else { return }
        do {
            try self.database.write { db in
                let tracklist = try self.findOrCreatePlaylist(playlistId: playlistId, db: db)
                try TracklistStorageService.shared.upsertTrack(track, db: db)
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
            self.membershipVersion += 1
            NotificationCenter.default.post(name: .playlistMembershipChanged, object: nil)
        } catch {
            logger.error("Failed to add track '\(track.title)' to playlist '\(playlistId)': \(error)")
        }
    }

    func removeFromPlaylist(_ track: Track, playlistId: String) {
        guard self.isInPlaylist(track, playlistId: playlistId) else { return }
        do {
            try self.database.write { db in
                try StoredTracklistTrack
                    .where {
                        $0.tracklistMediaId.eq(playlistId)
                            .and($0.tracklistMediaSourceId.eq("boppa.app"))
                            .and($0.trackMediaId.eq(track.mediaId))
                            .and($0.trackMediaSourceId.eq(track.mediaSourceId))
                    }
                    .delete()
                    .execute(db)
            }
            self.membershipVersion += 1
            NotificationCenter.default.post(name: .playlistMembershipChanged, object: nil)
        } catch {
            logger.error("Failed to remove track '\(track.title)' from playlist '\(playlistId)': \(error)")
        }
    }

    func togglePlaylist(_ track: Track, playlistId: String) {
        if self.isInPlaylist(track, playlistId: playlistId) {
            self.removeFromPlaylist(track, playlistId: playlistId)
        } else {
            self.addToPlaylist(track, playlistId: playlistId)
        }
    }

    private func findOrCreatePlaylist(playlistId: String, db: Database) throws -> StoredTracklist {
        let existing = try StoredTracklist
            .where { $0.mediaId.eq(playlistId).and($0.mediaSourceId.eq("boppa.app")) }
            .fetchOne(db)
        guard existing == nil else { return existing! }
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
                fromArtistMediaId: nil,
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
