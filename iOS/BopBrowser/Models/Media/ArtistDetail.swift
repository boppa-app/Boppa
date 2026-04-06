import Foundation

struct ArtistDetail {
    let songs: [Track]
    let albums: [Album]
    let videos: [Track]

    var isEmpty: Bool {
        self.songs.isEmpty && self.albums.isEmpty && self.videos.isEmpty
    }
}
