import Foundation

@MainActor
@Observable
class MediaSourceDetailViewModel {
    var mediaSource: MediaSource

    var isSourceEnabled: Bool {
        get { self.mediaSource.isEnabled }
        set {
            self.mediaSource.isEnabled = newValue
            try? MediaSourceStorageManager.shared.setEnabled(id: self.mediaSource.id, isEnabled: newValue)
            let name: Notification.Name = newValue ? .mediaSourceEnabled : .mediaSourceDisabled
            NotificationCenter.default.post(name: name, object: nil, userInfo: ["id": self.mediaSource.id])
        }
    }

    init(mediaSource: MediaSource) {
        self.mediaSource = mediaSource
    }
}
