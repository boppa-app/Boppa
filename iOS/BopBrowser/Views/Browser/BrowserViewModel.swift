import Foundation
import os
import SwiftUI
import WebKit

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "BopBrowser",
    category: "BrowserViewModel"
)

@Observable
@MainActor
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
        self.webView = Self.createWebView()
        super.init()
        self.configureWebView()
    }

    private static func createWebView() -> WKWebView {
        let webView = WebViewFactory.makeWebView(
            contractScript: getDomVisibilityScript().source,
            isHidden: false
        )

        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.isScrollEnabled = true
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.frame = .zero
        webView.transform = .identity

        return webView
    }

    private func configureWebView() {
        self.webView.navigationDelegate = self
        self.setupInteractionDetection()
        self.observeWebView()
    }

    private var lastAttemptedInput: String?

    func loadURL(urlString: String) {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            self.clearPage()
            return
        }

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

    func clearPage() {
        self.urlObservation = nil
        self.canGoBackObservation = nil
        self.canGoForwardObservation = nil
        self.isLoadingObservation = nil
        self.webView.stopLoading()
        self.webView.navigationDelegate = nil
        self.webView.scrollView.delegate = nil

        self.webView = Self.createWebView()
        self.configureWebView()

        self.currentURL = nil
        self.canGoBack = false
        self.canGoForward = false
        self.isLoading = false
        self.lastAttemptedInput = nil
        self.showBars()
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

    private func setupInteractionDetection() {
        self.webView.scrollView.delegate = self
    }

    private func observeWebView() {
        self.urlObservation = self.webView.observe(\.url, options: .new) { [weak self] webView, _ in
            MainActor.assumeIsolated {
                self?.currentURL = webView.url
            }
        }
        self.canGoBackObservation = self.webView.observe(\.canGoBack, options: .new) { [weak self] webView, _ in
            MainActor.assumeIsolated {
                self?.canGoBack = webView.canGoBack
            }
        }
        self.canGoForwardObservation = self.webView.observe(\.canGoForward, options: .new) { [weak self] webView, _ in
            MainActor.assumeIsolated {
                self?.canGoForward = webView.canGoForward
            }
        }
        self.isLoadingObservation = self.webView.observe(\.isLoading, options: .new) { [weak self] webView, _ in
            MainActor.assumeIsolated {
                self?.isLoading = webView.isLoading
            }
        }
    }
}

extension BrowserViewModel: UIScrollViewDelegate {
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        guard !self.barsHidden, self.currentURL != nil else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            self.hideBars()
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
