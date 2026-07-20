import Foundation

@MainActor
@Observable
class MediaSourceDetailViewModel {
    var mediaSource: StoredMediaSource

    var isContextGathered: Bool {
        self.mediaSource.isContextGathered
    }

    var isSourceEnabled: Bool {
        get { self.mediaSource.isEnabled }
        set {
            self.mediaSource.isEnabled = newValue
            try? MediaSourceStorageManager.shared.setEnabled(id: self.mediaSource.id, isEnabled: newValue)
            let name: Notification.Name = newValue ? .mediaSourceEnabled : .mediaSourceDisabled
            NotificationCenter.default.post(name: name, object: nil, userInfo: ["id": self.mediaSource.id])
        }
    }

    var isAutoUpdateEnabled: Bool {
        get { self.mediaSource.autoUpdate }
        set {
            self.mediaSource.autoUpdate = newValue
            try? MediaSourceStorageManager.shared.setAutoUpdate(id: self.mediaSource.id, autoUpdate: newValue)
        }
    }

    var isClearingWebData = false

    init(mediaSource: StoredMediaSource) {
        self.mediaSource = mediaSource
    }

    func clearWebData(completion: (() -> Void)? = nil) {
        self.isClearingWebData = true
        WebDataStore.shared.clearData(forUrls: self.mediaSource.config.effectiveAllowedUrls) { [weak self] in
            self?.isClearingWebData = false
            completion?()
        }
    }
}
