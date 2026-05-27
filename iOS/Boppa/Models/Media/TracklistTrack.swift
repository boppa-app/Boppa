import Foundation
import SQLiteData

@Table("tracklistTracks")
nonisolated struct TracklistTrack: Identifiable {
    let id: Int
    var tracklistId: Int
    var trackId: Int
    var sortOrder: Int
}
