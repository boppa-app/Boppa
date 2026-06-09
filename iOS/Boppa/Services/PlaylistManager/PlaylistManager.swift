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

    private(set) var trackPlaylists: [String: Set<String>] = [:]

    private init() {
        self.loadTrackMemberships()
    }

    func isInPlaylist(_ track: Track, playlistId: String) -> Bool {
        self.trackPlaylists[Self.key(for: track)]?.contains(playlistId) ?? false
    }

    func addToPlaylist(_ track: Track, playlistId: String) {
        guard !self.isInPlaylist(track, playlistId: playlistId) else { return }
        do {
            try self.database.write { db in
                let tracklist = try self.findOrCreatePlaylist(playlistId: playlistId, db: db)
                let trackId = try self.upsertTrack(track, db: db)
                let count = try StoredTracklistTrack
                    .where { $0.tracklistId.eq(tracklist.id) }
                    .fetchAll(db)
                    .count
                try StoredTracklistTrack.insert {
                    StoredTracklistTrack.Draft(tracklistId: tracklist.id, trackId: trackId, sortOrder: count)
                } onConflictDoUpdate: { $0.sortOrder = count }
                    .execute(db)
            }
            self.trackPlaylists[Self.key(for: track), default: []].insert(playlistId)
            NotificationCenter.default.post(name: .playlistMembershipChanged, object: nil)
        } catch {
            logger.error("Failed to add track '\(track.title)' to playlist '\(playlistId)': \(error)")
        }
    }

    func removeFromPlaylist(_ track: Track, playlistId: String) {
        guard self.isInPlaylist(track, playlistId: playlistId) else { return }
        do {
            try self.database.write { db in
                let tracklistRow = try StoredTracklist
                    .where { $0.mediaId.eq(playlistId).and($0.mediaSourceId.eq("boppa.app")) }
                    .fetchOne(db)
                guard let tracklist = tracklistRow else { return }
                let storedRow = try StoredTrack
                    .where { $0.mediaId.eq(track.mediaId).and($0.mediaSourceId.eq(track.mediaSourceId)) }
                    .fetchOne(db)
                guard let stored = storedRow else { return }
                try StoredTracklistTrack
                    .where { $0.tracklistId.eq(tracklist.id).and($0.trackId.eq(stored.id)) }
                    .delete()
                    .execute(db)
            }
            let trackKey = Self.key(for: track)
            self.trackPlaylists[trackKey]?.remove(playlistId)
            if self.trackPlaylists[trackKey]?.isEmpty == true {
                self.trackPlaylists.removeValue(forKey: trackKey)
            }
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

    private func loadTrackMemberships() {
        let memberships = (try? self.database.read { db -> [String: Set<String>] in
            let playlists = try StoredTracklist
                .where { $0.mediaSourceId.eq("boppa.app") }
                .fetchAll(db)

            var result: [String: Set<String>] = [:]
            for playlist in playlists {
                let joins = try StoredTracklistTrack
                    .where { $0.tracklistId.eq(playlist.id) }
                    .fetchAll(db)
                for join in joins {
                    if let track = try StoredTrack.where { $0.id.eq(join.trackId) }.fetchOne(db) {
                        let trackKey = "\(track.mediaId):::\(track.mediaSourceId)"
                        result[trackKey, default: []].insert(playlist.mediaId)
                    }
                }
            }
            return result
        }) ?? [:]
        self.trackPlaylists = memberships
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
                metadataJSON: Data(),
                fromArtistId: nil,
                isPinned: false,
                prevId: nil,
                nextId: nil
            )
        }.execute(db)
        let id = Int(db.lastInsertedRowID)
        return try StoredTracklist.where { $0.id.eq(id) }.fetchOne(db)!
    }

    private func upsertTrack(_ track: Track, db: Database) throws -> Int {
        let existing = try StoredTrack
            .where { $0.mediaId.eq(track.mediaId).and($0.mediaSourceId.eq(track.mediaSourceId)) }
            .fetchOne(db)
        guard existing == nil else { return existing!.id }
        try StoredTrack.insert {
            StoredTrack.Draft(
                mediaId: track.mediaId,
                mediaSourceId: track.mediaSourceId,
                title: track.title,
                subtitle: track.subtitle,
                duration: track.duration,
                artworkUrl: track.artworkUrl,
                url: track.url,
                metadataJSON: (try? JSONSerialization.data(withJSONObject: track.metadata)) ?? Data()
            )
        }.execute(db)
        return Int(db.lastInsertedRowID)
    }

    private static func key(for track: Track) -> String {
        "\(track.mediaId):::\(track.mediaSourceId)"
    }
}
