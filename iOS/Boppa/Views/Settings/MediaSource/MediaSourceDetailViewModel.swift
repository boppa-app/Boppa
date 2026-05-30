import Dependencies
import Foundation
import SQLiteData

@MainActor
@Observable
class MediaSourceDetailViewModel {
    var mediaSource: MediaSource

    @ObservationIgnored
    @Dependency(\.defaultDatabase) var database

    var showingLogin = false
    var isLoggedIn = false
    var isCheckingLogin = true

    var isSourceEnabled: Bool {
        get { self.mediaSource.isEnabled }
        set {
            self.mediaSource.isEnabled = newValue
            try? self.database.write { db in
                try MediaSource.update { $0.isEnabled = newValue }
                    .where { $0.id.eq(self.mediaSource.id) }
                    .execute(db)
            }
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
