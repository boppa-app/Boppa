import Foundation
import os
import WebKit

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "Boppa",
    category: "WebDataStore"
)

class WebDataStore {
    static let shared = WebDataStore()

    private let dataStore: WKWebsiteDataStore
    private var observers: [NSObjectProtocol] = []

    private init() {
        self.dataStore = WKWebsiteDataStore.default()
    }

    func getDataStore() -> WKWebsiteDataStore {
        return self.dataStore
    }

    func getCookies(forDomain domain: String) async -> [String: String] {
        let cookies = await self.dataStore.httpCookieStore.allCookies()
        var result: [String: String] = [:]
        for cookie in cookies {
            let cookieDomain = cookie.domain.hasPrefix(".") ? String(cookie.domain.dropFirst()) : cookie.domain
            if domain == cookieDomain || domain.hasSuffix(".\(cookieDomain)") {
                result[cookie.name] = cookie.value
            }
        }
        logger.debug("getCookies for '\(domain)': \(result.count) cookie(s)")
        return result
    }

    func checkCookiesExist(named cookieNames: [String], forDomain domain: String? = nil, completion: @escaping (Bool) -> Void) {
        self.dataStore.httpCookieStore.getAllCookies { cookies in
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

    func clearData(forUrls urls: [String], completion: (() -> Void)? = nil) {
        let hosts = Set(urls.compactMap { URL(string: $0)?.host })
        guard !hosts.isEmpty else {
            DispatchQueue.main.async { completion?() }
            return
        }

        func matches(_ domain: String) -> Bool {
            hosts.contains { host in
                host == domain || host.hasSuffix(".\(domain)") || domain.hasSuffix(".\(host)")
            }
        }

        let allDataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        self.dataStore.fetchDataRecords(ofTypes: allDataTypes) { records in
            let matchingRecords = records.filter { matches($0.displayName) }

            if let httpCookies = HTTPCookieStorage.shared.cookies {
                for cookie in httpCookies {
                    let cookieDomain = cookie.domain.hasPrefix(".") ? String(cookie.domain.dropFirst()) : cookie.domain
                    if matches(cookieDomain) {
                        HTTPCookieStorage.shared.deleteCookie(cookie)
                    }
                }
            }

            guard !matchingRecords.isEmpty else {
                logger.debug("clearData for \(hosts.count) host(s): no matching records")
                DispatchQueue.main.async { completion?() }
                return
            }

            self.dataStore.removeData(ofTypes: allDataTypes, for: matchingRecords) {
                logger.debug("clearData for \(hosts.count) host(s): removed \(matchingRecords.count) record(s)")
                DispatchQueue.main.async { completion?() }
            }
        }
    }
}
