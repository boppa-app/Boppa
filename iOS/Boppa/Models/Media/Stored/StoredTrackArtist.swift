import Foundation
import SQLiteData

@Table("trackArtists")
nonisolated struct StoredTrackArtist: Identifiable {
    let id: Int
    var trackId: Int
    var artistId: Int
    var sortOrder: Int
}
