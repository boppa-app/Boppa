import Foundation

enum RecentlyPlayedEntry: Identifiable {
    case track(Track)
    case album(AlbumGroup)

    struct AlbumGroup {
        let tracklist: Tracklist
        let tracks: [Track]
    }

    var id: String {
        switch self {
        case let .track(track):
            "track|\(track.mediaSourceId)|\(track.mediaId)"
        case let .album(group):
            "album|\(group.tracklist.mediaSourceId)|\(group.tracklist.mediaId)"
        }
    }

    static func grouping(_ tracks: [Track]) -> [RecentlyPlayedEntry] {
        func albumKey(_ track: Track) -> String? {
            guard let album = track.albums.first else { return nil }
            return "\(album.mediaSourceId)|\(album.mediaId)"
        }

        var countsByKey: [String: Int] = [:]
        for track in tracks {
            guard let key = albumKey(track) else { continue }
            countsByKey[key, default: 0] += 1
        }

        var seenKeys: Set<String> = []
        var entries: [RecentlyPlayedEntry] = []
        for track in tracks {
            if let key = albumKey(track), let album = track.albums.first,
               countsByKey[key, default: 0] >= 2
            {
                guard !seenKeys.contains(key) else { continue }
                seenKeys.insert(key)
                let groupTracks = tracks.filter { albumKey($0) == key }
                entries.append(.album(AlbumGroup(tracklist: album, tracks: groupTracks)))
            } else {
                entries.append(.track(track))
            }
        }
        return entries
    }

    static func flattenedOrder(_ tracks: [Track]) -> [Track] {
        self.grouping(tracks).flatMap { entry -> [Track] in
            switch entry {
            case let .track(track):
                [track]
            case let .album(group):
                group.tracks
            }
        }
    }
}
