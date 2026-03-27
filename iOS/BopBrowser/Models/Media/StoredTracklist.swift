import Foundation
import SwiftData

enum TracklistSortMode: String, CaseIterable {
    case defaultOrder = "default"
    case reversed
    case artistAZ
    case artistZA
    case songAZ
    case songZA

    var label: String {
        switch self {
        case .defaultOrder: return "Default Order"
        case .reversed: return "Reversed"
        case .artistAZ: return "Artist (A→Z)"
        case .artistZA: return "Artist (Z→A)"
        case .songAZ: return "Song (A→Z)"
        case .songZA: return "Song (Z→A)"
        }
    }

    var icon: String {
        switch self {
        case .defaultOrder: return "list.number"
        case .reversed: return "arrow.up.arrow.down"
        case .artistAZ: return "person.fill"
        case .artistZA: return "person.fill"
        case .songAZ: return "music.note"
        case .songZA: return "music.note"
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
    var songs: [StoredSong] = []

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

    var songCount: Int {
        self.songs.count
    }
}
