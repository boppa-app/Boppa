import Foundation

enum SearchCategory: String, CaseIterable {
    case songs
    case artists
    case albums
    case playlists

    var icon: String {
        switch self {
        case .songs: return "music.note"
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
        case .artists: return .artists([])
        case .albums: return .albums([])
        case .playlists: return .playlists([])
        }
    }

    func isAvailable(in data: MediaSourceData) -> Bool {
        switch self {
        case .songs: return !(data.searchSongs ?? []).isEmpty
        case .artists: return !(data.searchArtists ?? []).isEmpty
        case .albums: return !(data.searchAlbums ?? []).isEmpty
        case .playlists: return !(data.searchPlaylists ?? []).isEmpty
        }
    }
}
