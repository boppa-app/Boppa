import Foundation
import Observation

extension Notification.Name {
    static let navigateToArtistInSearch = Notification.Name("navigateToArtistInSearch")
    static let navigateToTracklistInSearch = Notification.Name("navigateToTracklistInSearch")
    static let navigateToTracklistInLibrary = Notification.Name("navigateToTracklistInLibrary")
}

func postTracklistNavigation(_ tracklist: Tracklist) {
    let isSavedToLibrary = TracklistStorageManager.shared.findStoredTracklist(
        mediaId: tracklist.mediaId,
        mediaSourceId: tracklist.mediaSourceId
    )?.isSavedToLibrary == true
    NotificationCenter.default.post(
        name: isSavedToLibrary ? .navigateToTracklistInLibrary : .navigateToTracklistInSearch,
        object: tracklist
    )
}

/// Broadcasts a tab's "reset to root" event by reference so deeply nested destinations
/// (pushed several navigationDestination levels down) observe it directly via Observation.
@Observable
final class NavigationResetSignal {
    private(set) var id = 0

    func fire() {
        self.id += 1
    }
}
