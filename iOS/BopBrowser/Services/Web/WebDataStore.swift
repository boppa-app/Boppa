import Foundation
import os
import WebKit

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "BopBrowser",
    category: "WebDataStore"
)

class WebDataStore {
    static let shared = WebDataStore()

    private let mobileDataStore: WKWebsiteDataStore
    private let desktopDataStore: WKWebsiteDataStore
    private var observers: [NSObjectProtocol] = []

    private init() {
        self.mobileDataStore = WKWebsiteDataStore.default()
        self.desktopDataStore = WKWebsiteDataStore.default()
    }

    func getDataStore() -> WKWebsiteDataStore {
        return self.mobileDataStore
    }

    func getDesktopDataStore() -> WKWebsiteDataStore {
        return self.desktopDataStore
    }

    func getCookies(forDomain domain: String, useDesktopStore: Bool) async -> [String: String] {
        let store = useDesktopStore ? self.desktopDataStore : self.mobileDataStore
        let cookies = await store.httpCookieStore.allCookies()
        var result: [String: String] = [:]
        for cookie in cookies {
            let cookieDomain = cookie.domain.hasPrefix(".") ? String(cookie.domain.dropFirst()) : cookie.domain
            if domain == cookieDomain || domain.hasSuffix(".\(cookieDomain)") {
                result[cookie.name] = cookie.value
            }
        }
        logger.debug("getCookies for '\(domain)': \(result.count) cookie(s) (desktop: \(useDesktopStore))")
        return result
    }

    func checkCookiesExist(named cookieNames: [String], forDomain domain: String? = nil, useDesktopStore: Bool = false, completion: @escaping (Bool) -> Void) {
        let store = useDesktopStore ? self.desktopDataStore : self.mobileDataStore
        store.httpCookieStore.getAllCookies { cookies in
            let validCookies = cookies.filter { cookie in
                guard cookie.expiresDate == nil || cookie.expiresDate! > Date() else {
                    return false
                }
                if let domain {
                    let cookieDomain = cookie.domain.hasPrefix(".") ? String(cookie.domain.dropFirst()) : cookie.domain
                    return domain == cookieDomain || domain.hasSuffix(".\(cookieDomain)")
                }
                return true
            }
            let validCookieNames = Set(validCookies.map(\.name))
            let allFound = cookieNames.allSatisfy { validCookieNames.contains($0) }
            DispatchQueue.main.async {
                completion(allFound)
            }
        }
    }

    func clearAllData(completion: (() -> Void)? = nil) {
        let group = DispatchGroup()
        let allDataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        let since = Date.distantPast

        group.enter()
        self.mobileDataStore.removeData(ofTypes: allDataTypes, modifiedSince: since) {
            group.leave()
        }

        group.enter()
        self.desktopDataStore.removeData(ofTypes: allDataTypes, modifiedSince: since) {
            group.leave()
        }

        if let httpCookies = HTTPCookieStorage.shared.cookies {
            for cookie in httpCookies {
                HTTPCookieStorage.shared.deleteCookie(cookie)
            }
        }

        group.notify(queue: .main) {
            completion?()
        }
    }
}
