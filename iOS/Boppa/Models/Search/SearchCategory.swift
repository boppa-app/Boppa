import Foundation

enum SearchCategory: String, CaseIterable, Hashable {
    case songs
    case videos
    case artists
    case albums
    case playlists

    var icon: String {
        switch self {
        case .songs: return "music.note"
        case .videos: return "video.fill"
        case .artists: return "person.fill"
        case .albums:
            if #available(iOS 26.0, *) {
                return "music.note.square.stack.fill"
            } else {
                return "square.stack.fill"
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

    func isAvailable(in search: SearchScripts) -> Bool {
        switch self {
        case .songs: return search.songs != nil
        case .videos: return search.videos != nil
        case .artists: return search.artists != nil
        case .albums: return search.albums != nil
        case .playlists: return search.playlists != nil
        }
    }

    func script(from search: SearchScripts) -> String? {
        switch self {
        case .songs: return search.songs
        case .videos: return search.videos
        case .artists: return search.artists
        case .albums: return search.albums
        case .playlists: return search.playlists
        }
    }
}

extension SearchCategory: CategoryBarItem {
    var displayName: String {
        rawValue.prefix(1).uppercased() + rawValue.dropFirst()
    }
}
