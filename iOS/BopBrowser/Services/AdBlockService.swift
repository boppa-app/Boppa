import Foundation
import WebKit
import os

@Observable
final class AdBlockService {
    static let shared = AdBlockService()

    private let contentBlockerURL = URL(string: "https://easylist-downloads.adblockplus.org/easylist_content_blocker.json")!
    private let cacheFileName = "adblock_rules.json"
    private let lastFetchKey = "AdBlockService.lastFetchTimestamp"
    private let refreshInterval: TimeInterval = 24 * 60 * 60
    private let ruleListIdentifier = "BopBrowserAdBlock"
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "BopBrowser", category: "AdBlockService")

    private(set) var isReady = false
    private var compiledRuleList: WKContentRuleList?

    private var cacheFileURL: URL {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return cacheDir.appendingPathComponent(cacheFileName)
    }

    private init() {}

    func loadContentRuleList() async {
        if shouldFetchNewRules() {
            await downloadAndCacheRules()
        }
        await compileRulesFromCache()
        await MainActor.run {
            self.isReady = true
        }
    }

    func getCompiledRuleList() -> WKContentRuleList? {
        return compiledRuleList
    }

    private func shouldFetchNewRules() -> Bool {
        guard FileManager.default.fileExists(atPath: cacheFileURL.path) else {
            return true
        }

        let lastFetch = UserDefaults.standard.double(forKey: lastFetchKey)
        let elapsed = Date().timeIntervalSince1970 - lastFetch
        return elapsed >= refreshInterval
    }

    private func downloadAndCacheRules() async {
        do {
            let (data, _) = try await URLSession.shared.data(from: contentBlockerURL)
            _ = try JSONSerialization.jsonObject(with: data, options: [])
            try data.write(to: cacheFileURL, options: .atomic)
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastFetchKey)
            logger.info("Cached content blocker rules (\(data.count) bytes)")
        } catch {
            logger.error("Failed to download or cache rules: \(error.localizedDescription)")
        }
    }

    private func compileRulesFromCache() async {
        guard FileManager.default.fileExists(atPath: cacheFileURL.path) else {
            logger.warning("No cached rules file to compile")
            return
        }
        do {
            let jsonString = try String(contentsOf: cacheFileURL, encoding: .utf8)

            let ruleList = try await WKContentRuleListStore.default().compileContentRuleList(
                forIdentifier: ruleListIdentifier,
                encodedContentRuleList: jsonString
            )

            compiledRuleList = ruleList
            logger.info("Compiled content rule list successfully")
        } catch {
            logger.error("Failed to compile rules: \(error.localizedDescription)")
        }
    }
}
