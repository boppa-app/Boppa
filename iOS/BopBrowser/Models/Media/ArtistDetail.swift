import Foundation

struct ArtistDetail {
    let songs: [Track]?
    let albums: [Album]?
    let videos: [Track]?
    let playlists: [Playlist]?
    let metadata: [String: Any]

    var isEmpty: Bool {
        (self.songs ?? []).isEmpty
            && (self.albums ?? []).isEmpty
            && (self.videos ?? []).isEmpty
            && (self.playlists ?? []).isEmpty
    }

    init(
        songs: [Track]? = nil,
        albums: [Album]? = nil,
        videos: [Track]? = nil,
        playlists: [Playlist]? = nil,
        metadata: [String: Any] = [:]
    ) {
        self.songs = songs
        self.albums = albums
        self.videos = videos
        self.playlists = playlists
        self.metadata = metadata
    }
}
