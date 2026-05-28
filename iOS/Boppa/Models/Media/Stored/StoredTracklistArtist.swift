import Foundation
import SQLiteData

@Table("tracklistArtists")
nonisolated struct StoredTracklistArtist: Identifiable {
    let id: Int
    var tracklistId: Int
    var artistId: Int
    var sortOrder: Int
}
