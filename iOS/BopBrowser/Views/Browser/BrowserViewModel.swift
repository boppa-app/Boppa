import Foundation
import os
import SwiftUI
import WebKit

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "BopBrowser",
    category: "BrowserViewModel"
)

@Observable
class BrowserViewModel: NSObject {
    var currentURL: URL?
    var isLoading: Bool = false
    var canGoBack: Bool = false
    var canGoForward: Bool = false
    var barsHidden: Bool = false

    private(set) var webView: WKWebView

    private var urlObservation: NSKeyValueObservation?
    private var canGoBackObservation: NSKeyValueObservation?
    private var canGoForwardObservation: NSKeyValueObservation?
    private var isLoadingObservation: NSKeyValueObservation?

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = WebDataStore.shared.getDataStore()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.userContentController.addUserScript(getDomVisibilityScript())

        if let ruleList = AdBlockService.shared.getCompiledRuleList() {
            configuration.userContentController.add(ruleList)
            logger.debug("Ad block content rule list applied")
        }

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = false
        webView.backgroundColor = .clear
        self.webView = webView

        super.init()

        self.webView.navigationDelegate = self
        self.setupScrollDetection()
        self.observeWebView()
    }

    private var lastAttemptedInput: String?

    func loadURL(urlString: String) {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        self.lastAttemptedInput = trimmed

        var urlToLoad = trimmed
        if !urlToLoad.hasPrefix("http://"), !urlToLoad.hasPrefix("https://") {
            urlToLoad = "https://" + urlToLoad
        }
        if let url = URL(string: urlToLoad) {
            self.currentURL = url
            self.webView.load(URLRequest(url: url))
        } else {
            self.performGoogleSearch(query: trimmed)
        }
    }

    private func performGoogleSearch(query: String) {
        self.lastAttemptedInput = nil
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        if let searchURL = URL(string: "https://www.google.com/search?q=\(encoded)") {
            self.currentURL = searchURL
            self.webView.load(URLRequest(url: searchURL))
        }
    }

    func goBack() {
        self.webView.goBack()
    }

    func goForward() {
        self.webView.goForward()
    }

    func refresh() {
        self.webView.reload()
    }

    func stop() {
        self.webView.stopLoading()
    }

    func showBars() {
        self.barsHidden = false
    }

    func hideBars() {
        self.barsHidden = true
    }

    var displayHost: String {
        guard let url = currentURL else { return "" }
        return url.host ?? url.absoluteString
    }

    private func setupScrollDetection() {
        self.webView.scrollView.delegate = self
    }

    private func observeWebView() {
        self.urlObservation = self.webView.observe(\.url, options: .new) { [weak self] webView, _ in
            self?.currentURL = webView.url
        }
        self.canGoBackObservation = self.webView.observe(\.canGoBack, options: .new) { [weak self] webView, _ in
            self?.canGoBack = webView.canGoBack
        }
        self.canGoForwardObservation = self.webView.observe(\.canGoForward, options: .new) { [weak self] webView, _ in
            self?.canGoForward = webView.canGoForward
        }
        self.isLoadingObservation = self.webView.observe(\.isLoading, options: .new) { [weak self] webView, _ in
            self?.isLoading = webView.isLoading
        }
    }
}

extension BrowserViewModel: UIScrollViewDelegate {
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        guard !self.barsHidden else { return }
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.3)) {
                self.hideBars()
            }
        }
    }
}

extension BrowserViewModel: WKNavigationDelegate {
    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        guard let input = self.lastAttemptedInput else { return }
        logger.debug("Navigation failed for '\(input)', falling back to Google search: \(error.localizedDescription)")
        self.performGoogleSearch(query: input)
    }
}
