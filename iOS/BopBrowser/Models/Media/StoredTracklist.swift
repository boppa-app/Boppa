import Foundation
import SwiftData

enum TracklistSortMode: String, CaseIterable {
    case defaultOrder = "default"
    case reversed
    case authorAZ
    case authorZA
    case nameAZ
    case nameZA

    var label: String {
        switch self {
        case .defaultOrder: return "Default Order"
        case .reversed: return "Reversed"
        case .authorAZ: return "Author (A→Z)"
        case .authorZA: return "Author (Z→A)"
        case .nameAZ: return "Name (A→Z)"
        case .nameZA: return "Name (Z→A)"
        }
    }

    var icon: String {
        switch self {
        case .defaultOrder: return "list.number"
        case .reversed: return "arrow.up.arrow.down"
        case .authorAZ: return "person.fill"
        case .authorZA: return "person.fill"
        case .nameAZ: return "music.note"
        case .nameZA: return "music.note"
        }
    }
}

@Model
final class StoredTracklist {
    var id: String
    var name: String
    var subtitle: String?
    var mediaSourceId: String
    var artworkUrl: String?
    var tracklistType: String
    var sortModeRaw: String = TracklistSortMode.defaultOrder.rawValue
    var metadataJSON: Data = Data()
    var isPinned: Bool = false

    @Relationship(deleteRule: .cascade)
    var tracks: [StoredTrack] = []

    var sortMode: TracklistSortMode {
        get { TracklistSortMode(rawValue: self.sortModeRaw) ?? .defaultOrder }
        set { self.sortModeRaw = newValue.rawValue }
    }

    var metadata: [String: Any] {
        guard let dict = try? JSONSerialization.jsonObject(with: self.metadataJSON) as? [String: Any] else {
            return [:]
        }
        return dict
    }

    init(
        id: String,
        name: String,
        subtitle: String? = nil,
        mediaSourceId: String,
        artworkUrl: String? = nil,
        tracklistType: String,
        metadata: [String: Any] = [:]
    ) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.mediaSourceId = mediaSourceId
        self.artworkUrl = artworkUrl
        self.tracklistType = tracklistType
        self.metadataJSON = (try? JSONSerialization.data(withJSONObject: metadata)) ?? Data()
    }

    var trackCount: Int {
        self.tracks.count
    }
}
