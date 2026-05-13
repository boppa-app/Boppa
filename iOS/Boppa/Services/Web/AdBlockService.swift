import Foundation
import os
import WebKit

@Observable
final class AdBlockService {
    static let shared = AdBlockService()

    private let contentBlockerURL = URL(string: "https://easylist-downloads.adblockplus.org/easylist_content_blocker.json")!
    private let lastFetchKey = "AdBlockService.lastFetchTimestamp"
    private let refreshInterval: TimeInterval = 24 * 60 * 60
    private let ruleListIdentifier = "BoppaAdBlock"
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Boppa", category: "AdBlockService")

    private(set) var isReady = false
    private var compiledRuleList: WKContentRuleList?

    private init() {}

    func loadContentRuleList() async {
        let needsFresh = self.shouldFetchNewRules()

        if !needsFresh {
            if let existing = await lookUpExistingRuleList() {
                self.compiledRuleList = existing
                self.logger.info("Loaded pre-compiled content rule list from store")
                await MainActor.run { self.isReady = true }
                return
            }
        }

        await self.downloadAndCompileRules()
        await MainActor.run {
            self.isReady = true
        }
    }

    func getCompiledRuleList() -> WKContentRuleList? {
        return self.compiledRuleList
    }

    private func shouldFetchNewRules() -> Bool {
        let lastFetch = UserDefaults.standard.double(forKey: self.lastFetchKey)
        guard lastFetch > 0 else { return true }
        let elapsed = Date().timeIntervalSince1970 - lastFetch
        return elapsed >= self.refreshInterval
    }

    private func lookUpExistingRuleList() async -> WKContentRuleList? {
        do {
            return try await WKContentRuleListStore.default().contentRuleList(forIdentifier: self.ruleListIdentifier)
        } catch {
            self.logger.warning("No pre-compiled rule list found in store: \(error.localizedDescription)")
            return nil
        }
    }

    private func downloadAndCompileRules() async {
        do {
            let (data, _) = try await URLSession.shared.data(from: self.contentBlockerURL)

            guard let jsonString = String(data: data, encoding: .utf8) else {
                self.logger.error("Failed to decode downloaded rules as UTF-8")
                return
            }

            _ = try JSONSerialization.jsonObject(with: data, options: [])

            let ruleList = try await WKContentRuleListStore.default().compileContentRuleList(
                forIdentifier: self.ruleListIdentifier,
                encodedContentRuleList: jsonString
            )

            self.compiledRuleList = ruleList
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: self.lastFetchKey)
            self.logger.info("Downloaded and compiled content rule list (\(data.count) bytes)")
        } catch {
            self.logger.error("Failed to download or compile rules: \(error.localizedDescription)")

            if let fallback = await lookUpExistingRuleList() {
                self.compiledRuleList = fallback
                self.logger.info("Fell back to previously compiled rule list")
            }
        }
    }
}
