import Foundation

struct Tracklist {
    let name: String
    let artist: Artist?
    let mediaSourceName: String
    let artworkUrl: String?
    let tracklistType: TracklistType
    let storedTracklist: StoredTracklist?

    enum TracklistType {
        case likes
        case album(Album)
        case playlist(Playlist)
        case artistSongs(Artist, ArtistDetail)
        case artistVideos(Artist, ArtistDetail)
    }

    var isPersisted: Bool {
        self.storedTracklist != nil
    }

    var isLikes: Bool {
        if case .likes = self.tracklistType { return true }
        return false
    }

    var album: Album? {
        if case let .album(album) = self.tracklistType { return album }
        return nil
    }

    var playlist: Playlist? {
        if case let .playlist(playlist) = self.tracklistType { return playlist }
        return nil
    }

    init(storedTracklist: StoredTracklist) {
        self.name = storedTracklist.name
        self.artist = nil
        self.mediaSourceName = storedTracklist.mediaSourceName
        self.artworkUrl = storedTracklist.artworkUrl
        self.storedTracklist = storedTracklist

        switch storedTracklist.tracklistType {
        case "likes":
            self.tracklistType = .likes
        default:
            self.tracklistType = .playlist(Playlist(id: storedTracklist.id, title: storedTracklist.name))
        }
    }

    init(album: Album, mediaSourceName: String) {
        self.name = album.title
        self.artist = nil
        self.mediaSourceName = mediaSourceName
        self.artworkUrl = album.artworkUrl
        self.tracklistType = .album(album)
        self.storedTracklist = nil
    }

    init(playlist: Playlist, mediaSourceName: String) {
        self.name = playlist.title
        self.artist = nil
        self.mediaSourceName = mediaSourceName
        self.artworkUrl = playlist.artworkUrl
        self.tracklistType = .playlist(playlist)
        self.storedTracklist = nil
    }

    init(artist: Artist, type: TracklistType, mediaSourceName: String) {
        self.artist = artist
        self.mediaSourceName = mediaSourceName
        self.artworkUrl = artist.artworkUrl
        self.storedTracklist = nil
        self.tracklistType = type

        switch type {
        case .artistSongs:
            self.name = "Songs"
        case .artistVideos:
            self.name = "Videos"
        default:
            self.name = artist.name
        }
    }
}
