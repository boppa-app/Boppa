import Foundation
import SQLiteData

@Table("trackAlbums")
nonisolated struct StoredTrackAlbum: Identifiable {
    let id: Int
    var trackId: Int
    var tracklistId: Int
    var sortOrder: Int
}
