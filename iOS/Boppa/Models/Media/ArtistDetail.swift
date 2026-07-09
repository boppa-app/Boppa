import Foundation

enum ArtistDetailSection: String {
    case songs
    case albums
    case videos
    case playlists
}

struct ArtistDetail {
    let lowResArtworkUrl: String?
    let highResArtworkUrl: String?
    let songs: [Track]?
    let albums: [Tracklist]?
    let videos: [Track]?
    let playlists: [Tracklist]?
    let sectionOrder: [ArtistDetailSection]

    var isEmpty: Bool {
        (self.songs ?? []).isEmpty
            && (self.albums ?? []).isEmpty
            && (self.videos ?? []).isEmpty
            && (self.playlists ?? []).isEmpty
    }

    init(
        lowResArtworkUrl: String? = nil,
        highResArtworkUrl: String? = nil,
        songs: [Track]? = nil,
        albums: [Tracklist]? = nil,
        videos: [Track]? = nil,
        playlists: [Tracklist]? = nil,
        sectionOrder: [ArtistDetailSection] = [.songs, .albums, .videos, .playlists]
    ) {
        self.lowResArtworkUrl = lowResArtworkUrl
        self.highResArtworkUrl = highResArtworkUrl
        self.songs = songs
        self.albums = albums
        self.videos = videos
        self.playlists = playlists
        self.sectionOrder = sectionOrder
    }
}
