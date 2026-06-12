import Foundation
import SQLiteData

@Table("tracklistArtists")
nonisolated struct StoredTracklistArtist {
    @Column(primaryKey: true) var tracklistMediaId: String
    var tracklistMediaSourceId: String
    var artistMediaId: String
    var artistMediaSourceId: String
    var sortOrder: String
}
