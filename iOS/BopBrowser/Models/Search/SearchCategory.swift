import Foundation

enum SearchCategory: String, CaseIterable {
    case songs
    case videos
    case artists
    case albums
    case playlists

    var icon: String {
        switch self {
        case .songs: return "music.note"
        case .videos: return "video"
        case .artists: return "music.microphone"
        case .albums:
            if #available(iOS 26.0, *) {
                return "music.note.square.stack"
            } else {
                return "square.stack"
            }
        case .playlists: return "music.note.list"
        }
    }

    var emptyResult: SearchResult {
        switch self {
        case .songs: return .songs([])
        case .videos: return .videos([])
        case .artists: return .artists([])
        case .albums: return .albums([])
        case .playlists: return .playlists([])
        }
    }

    func isAvailable(in data: MediaSourceData) -> Bool {
        switch self {
        case .songs: return data.searchSongs != nil
        case .videos: return data.searchVideos != nil
        case .artists: return data.searchArtists != nil
        case .albums: return data.searchAlbums != nil
        case .playlists: return data.searchPlaylists != nil
        }
    }

    func script(from data: MediaSourceData) -> String? {
        switch self {
        case .songs: return data.searchSongs?.script
        case .videos: return data.searchVideos?.script
        case .artists: return data.searchArtists?.script
        case .albums: return data.searchAlbums?.script
        case .playlists: return data.searchPlaylists?.script
        }
    }
}
