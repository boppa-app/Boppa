import Foundation
import os
import WebKit

@Observable
final class AdBlockService {
    static let shared = AdBlockService()

    private let contentBlockerURL = URL(string: "https://easylist-downloads.adblockplus.org/easylist_content_blocker.json")!
    private let lastFetchKey = "AdBlockService.lastFetchTimestamp"
    private let refreshInterval: TimeInterval = 24 * 60 * 60
    private let ruleListIdentifier = "BopBrowserAdBlock"
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "BopBrowser", category: "AdBlockService")

    private(set) var isReady = false
    private var compiledRuleList: WKContentRuleList?

    private init() {}

    func loadContentRuleList() async {
        let needsFresh = shouldFetchNewRules()

        if !needsFresh {
            if let existing = await lookUpExistingRuleList() {
                compiledRuleList = existing
                logger.info("Loaded pre-compiled content rule list from store")
                await MainActor.run { self.isReady = true }
                return
            }
        }

        await downloadAndCompileRules()
        await MainActor.run {
            self.isReady = true
        }
    }

    func getCompiledRuleList() -> WKContentRuleList? {
        return compiledRuleList
    }

    private func shouldFetchNewRules() -> Bool {
        let lastFetch = UserDefaults.standard.double(forKey: lastFetchKey)
        guard lastFetch > 0 else { return true }
        let elapsed = Date().timeIntervalSince1970 - lastFetch
        return elapsed >= refreshInterval
    }

    private func lookUpExistingRuleList() async -> WKContentRuleList? {
        do {
            return try await WKContentRuleListStore.default().contentRuleList(forIdentifier: ruleListIdentifier)
        } catch {
            logger.warning("No pre-compiled rule list found in store: \(error.localizedDescription)")
            return nil
        }
    }

    private func downloadAndCompileRules() async {
        do {
            let (data, _) = try await URLSession.shared.data(from: contentBlockerURL)

            guard let jsonString = String(data: data, encoding: .utf8) else {
                logger.error("Failed to decode downloaded rules as UTF-8")
                return
            }

            _ = try JSONSerialization.jsonObject(with: data, options: [])

            let ruleList = try await WKContentRuleListStore.default().compileContentRuleList(
                forIdentifier: ruleListIdentifier,
                encodedContentRuleList: jsonString
            )

            compiledRuleList = ruleList
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastFetchKey)
            logger.info("Downloaded and compiled content rule list (\(data.count) bytes)")
        } catch {
            logger.error("Failed to download or compile rules: \(error.localizedDescription)")

            if let fallback = await lookUpExistingRuleList() {
                compiledRuleList = fallback
                logger.info("Fell back to previously compiled rule list")
            }
        }
    }
}
