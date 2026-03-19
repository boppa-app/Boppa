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

        if let ruleList = AdBlockService.shared.getCompiledRuleList() {
            webView.configuration.userContentController.add(ruleList)
            logger.debug("Ad block content rule list applied")
        }

        self.webView = webView

        super.init()

        self.webView.navigationDelegate = self
        self.setupInteractionDetection()
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

    private func setupInteractionDetection() {
        self.webView.scrollView.delegate = self
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.webViewInteracted))
        tapGesture.cancelsTouchesInView = false
        tapGesture.delegate = self
        self.webView.addGestureRecognizer(tapGesture)
    }

    @objc private func webViewInteracted() {
        guard !self.barsHidden, self.currentURL != nil else { return }
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.3)) {
                self.hideBars()
            }
        }
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
        self.webViewInteracted()
    }
}

extension BrowserViewModel: UIGestureRecognizerDelegate {
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        return true
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
