import Foundation

extension Notification.Name {
    static let navigateToArtistInSearch = Notification.Name("navigateToArtistInSearch")
    static let navigateToTracklistInSearch = Notification.Name("navigateToTracklistInSearch")
    static let navigateToTracklistInLibrary = Notification.Name("navigateToTracklistInLibrary")
    static let deepLinkAddMediaSource = Notification.Name("deepLinkAddMediaSource")
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
