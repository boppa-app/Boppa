import Foundation

enum ArtistDetailSection: String {
    case songs
    case albums
    case videos
    case playlists
}

struct ArtistDetail {
    let songs: [Track]?
    let albums: [Tracklist]?
    let videos: [Track]?
    let playlists: [Tracklist]?
    let metadata: [String: Any]
    let sectionOrder: [ArtistDetailSection]

    var isEmpty: Bool {
        (self.songs ?? []).isEmpty
            && (self.albums ?? []).isEmpty
            && (self.videos ?? []).isEmpty
            && (self.playlists ?? []).isEmpty
    }

    init(
        songs: [Track]? = nil,
        albums: [Tracklist]? = nil,
        videos: [Track]? = nil,
        playlists: [Tracklist]? = nil,
        metadata: [String: Any] = [:],
        sectionOrder: [ArtistDetailSection] = [.songs, .albums, .videos, .playlists]
    ) {
        self.songs = songs
        self.albums = albums
        self.videos = videos
        self.playlists = playlists
        self.metadata = metadata
        self.sectionOrder = sectionOrder
    }
}
