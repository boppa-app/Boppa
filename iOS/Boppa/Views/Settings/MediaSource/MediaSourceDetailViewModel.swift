import Foundation

@MainActor
@Observable
class MediaSourceDetailViewModel {
    var mediaSource: MediaSource

    var showingLogin = false
    var isLoggedIn = false
    var isCheckingLogin = true

    var isSourceEnabled: Bool {
        get { self.mediaSource.isEnabled }
        set {
            self.mediaSource.isEnabled = newValue
            try? MediaSourceStorageManager.shared.setEnabled(id: self.mediaSource.id, isEnabled: newValue)
            let name: Notification.Name = newValue ? .mediaSourceEnabled : .mediaSourceDisabled
            NotificationCenter.default.post(name: name, object: nil, userInfo: ["id": self.mediaSource.id])
        }
    }

    var loginURL: URL? {
        guard let urlString = self.mediaSource.config.login?.url else { return nil }
        return URL(string: urlString)
    }

    init(mediaSource: MediaSource) {
        self.mediaSource = mediaSource
        NotificationCenter.default.addObserver(
            forName: .mediaSourceLoginCompleted,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            guard let mediaSourceId = notification.userInfo?["mediaSourceId"] as? String,
                  mediaSourceId == self.mediaSource.id else { return }
            self.isLoggedIn = true
            self.isCheckingLogin = false
        }
    }

    func checkLoginStatus() {
        guard let cookieNames = self.mediaSource.config.login?.cookies, !cookieNames.isEmpty else {
            self.isCheckingLogin = false
            self.isLoggedIn = false
            return
        }

        self.isCheckingLogin = true
        let useDesktopStore = self.mediaSource.config.customUserAgent != nil
        let domain = URL(string: self.mediaSource.config.url)?.host
        WebDataStore.shared.checkCookiesExist(named: cookieNames, forDomain: domain, useDesktopStore: useDesktopStore) { exists in
            self.isLoggedIn = exists
            self.isCheckingLogin = false
        }
    }
}
