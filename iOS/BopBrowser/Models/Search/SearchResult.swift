import Foundation

enum SearchResult {
    case songs([Track])
    case albums([Album])
    case artists([Artist])
    case playlists([Playlist])

    var isEmpty: Bool {
        self.count == 0
    }

    var count: Int {
        switch self {
        case let .songs(items): return items.count
        case let .albums(items): return items.count
        case let .artists(items): return items.count
        case let .playlists(items): return items.count
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
