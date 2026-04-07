import Foundation

struct ArtistDetail {
    let songs: [Track]
    let albums: [Album]
    let videos: [Track]
    let metadata: [String: Any]

    var isEmpty: Bool {
        self.songs.isEmpty && self.albums.isEmpty && self.videos.isEmpty
    }

    init(
        songs: [Track],
        albums: [Album],
        videos: [Track],
        metadata: [String: Any] = [:]
    ) {
        self.songs = songs
        self.albums = albums
        self.videos = videos
        self.metadata = metadata
    }
}
