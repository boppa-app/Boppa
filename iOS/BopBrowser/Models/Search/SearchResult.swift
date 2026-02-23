import Foundation

enum SearchResult {
    case songs([Song])
    case albums([Album])
    case artists([Artist])
    case playlists([Playlist])

    var isEmpty: Bool {
        switch self {
        case let .songs(items): return items.isEmpty
        case let .albums(items): return items.isEmpty
        case let .artists(items): return items.isEmpty
        case let .playlists(items): return items.isEmpty
        }
    }
}
