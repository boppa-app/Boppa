import Foundation
import SQLiteData

@Table("trackArtists")
nonisolated struct StoredTrackArtist {
    @Column(primaryKey: true) var trackMediaId: String
    var trackMediaSourceId: String
    var artistMediaId: String
    var artistMediaSourceId: String
    var sortOrder: Int
}
