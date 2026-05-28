import Foundation
import SQLiteData

@Table("tracklistTracks")
nonisolated struct StoredTracklistTrack: Identifiable {
    let id: Int
    var tracklistId: Int
    var trackId: Int
    var sortOrder: Int
}
