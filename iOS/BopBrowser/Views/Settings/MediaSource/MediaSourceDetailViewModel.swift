import Foundation

@MainActor
@Observable
class MediaSourceDetailViewModel {
    let source: MediaSource

    var showingLogin = false
    var isLoggedIn = false
    var isCheckingLogin = true

    var loginURL: URL? {
        guard let urlString = self.source.config.login?.url else { return nil }
        return URL(string: urlString)
    }

    init(source: MediaSource) {
        self.source = source
        NotificationCenter.default.addObserver(
            forName: .mediaSourceLoginCompleted,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            guard let mediaSourceName = notification.userInfo?["mediaSourceName"] as? String,
                  mediaSourceName == self.source.name else { return }
            self.isLoggedIn = true
            self.isCheckingLogin = false
        }
    }

    func checkLoginStatus() {
        guard let cookieNames = self.source.config.login?.cookies, !cookieNames.isEmpty else {
            self.isCheckingLogin = false
            self.isLoggedIn = false
            return
        }

        self.isCheckingLogin = true
        let useDesktopStore = self.source.config.customUserAgent != nil
        let domain = URL(string: self.source.config.url)?.host
        WebDataStore.shared.checkCookiesExist(named: cookieNames, forDomain: domain, useDesktopStore: useDesktopStore) { exists in
            self.isLoggedIn = exists
            self.isCheckingLogin = false
        }
    }
}
