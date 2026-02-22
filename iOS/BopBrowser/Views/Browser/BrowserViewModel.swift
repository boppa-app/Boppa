import Foundation
import os
import WebKit

@Observable
class BrowserViewModel {
    var currentURL: URL?
    var isLoading: Bool = false
    var canGoBack: Bool = false
    var canGoForward: Bool = false

    private(set) var webView: WKWebView

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "BopBrowser",
        category: "BrowserViewModel"
    )

    private var urlObservation: NSKeyValueObservation?
    private var canGoBackObservation: NSKeyValueObservation?
    private var canGoForwardObservation: NSKeyValueObservation?
    private var isLoadingObservation: NSKeyValueObservation?

    init() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = WebDataStore.shared.getDataStore()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.userContentController.addUserScript(getDomVisibilityScript())

        if let ruleList = AdBlockService.shared.getCompiledRuleList() {
            configuration.userContentController.add(ruleList)
            self.logger.debug("Ad block content rule list applied")
        }

        self.webView = WKWebView(frame: .zero, configuration: configuration)
        self.webView.allowsBackForwardNavigationGestures = true
        self.webView.isOpaque = false
        self.webView.backgroundColor = .clear

        self.observeWebView()
    }

    func loadURL(urlString: String) {
        var urlToLoad = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !urlToLoad.hasPrefix("http://"), !urlToLoad.hasPrefix("https://") {
            urlToLoad = "https://" + urlToLoad
        }
        if let url = URL(string: urlToLoad) {
            self.currentURL = url
            self.webView.load(URLRequest(url: url))
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
