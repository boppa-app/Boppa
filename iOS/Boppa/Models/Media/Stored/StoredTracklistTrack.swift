import Foundation
import SQLiteData

@Table("tracklistTracks")
nonisolated struct StoredTracklistTrack {
    @Column(primaryKey: true) var tracklistMediaId: String
    var tracklistMediaSourceId: String
    var trackMediaId: String
    var trackMediaSourceId: String
    var sortOrder: Int
    var addedAt: Double
}
