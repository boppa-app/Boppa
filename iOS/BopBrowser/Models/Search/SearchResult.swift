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

    mutating func append(_ other: SearchResult) {
        switch (self, other) {
        case let (.songs(existing), .songs(new)):
            self = .songs(existing + new)
        case let (.albums(existing), .albums(new)):
            self = .albums(existing + new)
        case let (.artists(existing), .artists(new)):
            self = .artists(existing + new)
        case let (.playlists(existing), .playlists(new)):
            self = .playlists(existing + new)
        default:
            break
        }
    }
}
