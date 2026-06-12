import Foundation
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Boppa", category: "PlaylistManager")

extension Notification.Name {
    static let playlistMembershipChanged = Notification.Name("playlistMembershipChanged")
}

@Observable
@MainActor
class PlaylistManager {
    static let shared = PlaylistManager()

    /// Incremented on every add/remove so @Observable views re-evaluate isInPlaylist.
    private(set) var membershipVersion: Int = 0

    private init() {}

    func isInPlaylist(_ track: Track, playlistId: String) -> Bool {
        _ = self.membershipVersion
        return TrackStorageService.shared.isTrack(track, inPlaylist: playlistId)
    }

    func addToPlaylist(_ track: Track, playlistId: String) {
        do {
            try TrackStorageService.shared.addTrack(track, toPlaylist: playlistId)
            self.membershipVersion += 1
            NotificationCenter.default.post(name: .playlistMembershipChanged, object: nil)
        } catch {
            logger.error("Failed to add track '\(track.title)' to playlist '\(playlistId)': \(error)")
        }
    }

    func removeFromPlaylist(_ track: Track, playlistId: String) {
        do {
            try TrackStorageService.shared.removeTrack(track, fromPlaylist: playlistId)
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
}
