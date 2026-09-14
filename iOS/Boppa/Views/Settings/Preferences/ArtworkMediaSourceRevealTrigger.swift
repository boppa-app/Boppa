import Foundation

enum ArtworkMediaSourceRevealTrigger: String, CaseIterable, ThreeWaySliderOption {
    case off
    case singleTap
    case doubleTap

    static let storageKey = "artworkMediaSourceRevealTrigger"
    static let defaultValue = ArtworkMediaSourceRevealTrigger.singleTap

    var label: String {
        switch self {
        case .off: return "Off"
        case .singleTap: return "Single Tap"
        case .doubleTap: return "Double Tap"
        }
    }

    var tapCount: Int? {
        switch self {
        case .off: return nil
        case .singleTap: return 1
        case .doubleTap: return 2
        }
    }
}
