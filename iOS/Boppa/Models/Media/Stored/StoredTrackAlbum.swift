import Foundation
import SQLiteData

@Table("trackAlbums")
nonisolated struct StoredTrackAlbum {
    @Column(primaryKey: true) var trackMediaId: String
    var trackMediaSourceId: String
    var tracklistMediaId: String
    var tracklistMediaSourceId: String
    var sortOrder: String
}
