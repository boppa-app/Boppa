import Foundation

enum RecentlyViewedItem: Identifiable {
    case artist(Artist, viewedAt: Double)
    case tracklist(Tracklist, viewedAt: Double)

    var viewedAt: Double {
        switch self {
        case let .artist(_, viewedAt): viewedAt
        case let .tracklist(_, viewedAt): viewedAt
        }
    }

    var id: String {
        switch self {
        case let .artist(artist, _): "artist|\(artist.mediaId)|\(artist.mediaSourceId)"
        case let .tracklist(tracklist, _): "tracklist|\(tracklist.mediaId)|\(tracklist.mediaSourceId)"
        }
    }
}
