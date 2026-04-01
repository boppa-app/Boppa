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
    var name: String
    var mediaSourceName: String
    var artworkUrl: String?
    var tracklistType: String
    var remoteId: String?
    var sortModeRaw: String = TracklistSortMode.defaultOrder.rawValue

    @Relationship(deleteRule: .cascade)
    var tracks: [StoredTrack] = []

    var sortMode: TracklistSortMode {
        get { TracklistSortMode(rawValue: self.sortModeRaw) ?? .defaultOrder }
        set { self.sortModeRaw = newValue.rawValue }
    }

    init(
        name: String,
        mediaSourceName: String,
        artworkUrl: String? = nil,
        tracklistType: String,
        remoteId: String? = nil
    ) {
        self.name = name
        self.mediaSourceName = mediaSourceName
        self.artworkUrl = artworkUrl
        self.tracklistType = tracklistType
        self.remoteId = remoteId
    }

    var isLikes: Bool {
        self.tracklistType == "likes"
    }

    var trackCount: Int {
        self.tracks.count
    }
}
