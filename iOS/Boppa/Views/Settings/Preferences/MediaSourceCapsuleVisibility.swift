import Foundation

enum MediaSourceCapsuleVisibility: String, CaseIterable, ThreeWaySliderOption {
    case off
    case lists
    case everywhere

    static let storageKey = "mediaSourceCapsuleVisibility"
    static let defaultValue = MediaSourceCapsuleVisibility.lists

    var label: String {
        switch self {
        case .off: return "None"
        case .lists: return "Lists"
        case .everywhere: return "Everywhere"
        }
    }

    var showsOnTracks: Bool {
        self == .everywhere
    }

    var showsOnTracklists: Bool {
        self != .off
    }

    var showsOnArtists: Bool {
        self != .off
    }
}
