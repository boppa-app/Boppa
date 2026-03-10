import Combine
import os
import WebKit

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "BopBrowser",
    category: "LoginWebViewModel"
)

class LoginWebViewModel: NSObject, ObservableObject, WKHTTPCookieStoreObserver {
    let url: URL
    let customUserAgent: String?
    let mediaSourceName: String

    @Published var shouldDismiss = false

    private let requiredCookies: [String]
    private let cookieDomain: String?
    private var cookieStore: WKHTTPCookieStore?
    private var hasCompleted = false
    private var pollingTimer: Timer?

    init(url: URL, customUserAgent: String?, requiredCookies: [String], cookieDomain: String?, mediaSourceName: String) {
        self.url = url
        self.customUserAgent = customUserAgent
        self.requiredCookies = requiredCookies
        self.cookieDomain = cookieDomain
        self.mediaSourceName = mediaSourceName
        super.init()
    }

    func startMonitoring() {
        guard !self.requiredCookies.isEmpty else {
            logger.info("No required cookies configured, skipping auto-dismiss")
            return
        }

        let useDesktopStore = self.customUserAgent != nil
        logger.info("Starting cookie monitor for cookies: \(self.requiredCookies), domain: \(self.cookieDomain ?? "nil"), useDesktopStore: \(useDesktopStore)")

        let store = useDesktopStore
            ? WebDataStore.shared.getDesktopDataStore()
            : WebDataStore.shared.getDataStore()
        self.cookieStore = store.httpCookieStore
        self.cookieStore?.add(self)

        self.pollingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkCookies()
        }
    }

    func stopMonitoring() {
        logger.debug("Stopping cookie monitor")
        self.pollingTimer?.invalidate()
        self.pollingTimer = nil
        self.cookieStore?.remove(self)
        self.cookieStore = nil
    }

    func dismiss() {
        self.shouldDismiss = true
    }

    private func checkCookies() {
        guard !self.hasCompleted, let cookieStore = self.cookieStore else { return }

        cookieStore.getAllCookies { [weak self] cookies in
            guard let self, !self.hasCompleted else { return }

            let validCookies = cookies.filter { cookie in
                guard cookie.expiresDate == nil || cookie.expiresDate! > Date() else {
                    return false
                }
                if let domain = self.cookieDomain {
                    let cookieDomain = cookie.domain.hasPrefix(".") ? String(cookie.domain.dropFirst()) : cookie.domain
                    return domain == cookieDomain || domain.hasSuffix(".\(cookieDomain)")
                }
                return true
            }
            let validCookieNames = Set(validCookies.map(\.name))

            let found = self.requiredCookies.filter { validCookieNames.contains($0) }
            let missing = self.requiredCookies.filter { !validCookieNames.contains($0) }

            if missing.isEmpty {
                self.hasCompleted = true
                DispatchQueue.main.async {
                    logger.info("All required cookies found, auto-dismissing login modal")
                    self.pollingTimer?.invalidate()
                    self.pollingTimer = nil
                    NotificationCenter.default.post(
                        name: .mediaSourceLoginCompleted,
                        object: nil,
                        userInfo: ["mediaSourceName": self.mediaSourceName]
                    )
                    self.dismiss()
                }
            }
        }
    }
}
