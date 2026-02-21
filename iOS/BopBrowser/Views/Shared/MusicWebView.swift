import os
import SwiftUI
import WebKit

struct MusicWebView: UIViewRepresentable {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "BopBrowser", category: "BopBrowserApp")

    let url: URL?
    let isHidden: Bool
    let delegate: (any MusicWebViewDelegate)?

    init(
        url: URL?,
        isHidden: Bool = false,
        delegate: (any MusicWebViewDelegate)? = nil
    ) {
        self.url = url
        self.isHidden = isHidden
        self.delegate = delegate
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = WebDataStore.shared.getDataStore()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.userContentController.addUserScript(getDOMVisibilityScript())

        if let ruleList = AdBlockService.shared.getCompiledRuleList() {
            configuration.userContentController.add(ruleList)
            logger.debug("Ad block content rule list applied to webview configuration")
        } else {
            logger.debug("No ad block content rule list available")
        }

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = false
        webView.backgroundColor = UIColor(Color.clear)

        if isHidden {
            webView.isHidden = true
            webView.alpha = 0
        }

        context.coordinator.observe(webView)
        delegate?.webViewDidCreate(webView)

        if let url = url {
            let request = URLRequest(url: url)
            webView.load(request)
        }

        return webView
    }

    private func getDOMVisibilityScript() -> WKUserScript {
        let visibilityScript = """
            (function() {
            'use strict';
            
            Object.defineProperty(document, 'hidden', {
                configurable: true,
                get: function() {
                return false;
                }
            });
            
            Object.defineProperty(document, 'visibilityState', {
                configurable: true,
                get: function() {
                return 'visible';
                }
            });
            
            if ('webkitHidden' in document) {
                Object.defineProperty(document, 'webkitHidden', {
                configurable: true,
                get: function() {
                    return false;
                }
                });
            }
            
            if ('webkitVisibilityState' in document) {
                Object.defineProperty(document, 'webkitVisibilityState', {
                configurable: true,
                get: function() {
                    return 'visible';
                }
                });
            }
            
            const originalAddEventListener = document.addEventListener;
            document.addEventListener = function(type, listener, options) {
                if (type === 'visibilitychange' || type === 'webkitvisibilitychange') {
                return originalAddEventListener.call(this, type, listener, options);
                }
                return originalAddEventListener.call(this, type, listener, options);
            };
            
            Object.defineProperty(document, 'hasFocus', {
                configurable: true,
                value: function() {
                return true;
                }
            });
            })();
        """
        return WKUserScript(
            source: visibilityScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: MusicWebView
        private var urlObservation: NSKeyValueObservation?
        private var canGoBackObservation: NSKeyValueObservation?
        private var canGoForwardObservation: NSKeyValueObservation?
        private var isLoadingObservation: NSKeyValueObservation?

        init(_ parent: MusicWebView) {
            self.parent = parent
        }

        func observe(_ webView: WKWebView) {
            urlObservation = webView.observe(\.url, options: .new) { [weak self] webView, _ in
                self?.parent.delegate?.webView(webView, didUpdateURL: webView.url)
            }
            canGoBackObservation = webView.observe(\.canGoBack, options: .new) { [weak self] webView, _ in
                self?.parent.delegate?.webView(webView, didUpdateCanGoBack: webView.canGoBack)
            }
            canGoForwardObservation = webView.observe(\.canGoForward, options: .new) { [weak self] webView, _ in
                self?.parent.delegate?.webView(webView, didUpdateCanGoForward: webView.canGoForward)
            }
            isLoadingObservation = webView.observe(\.isLoading, options: .new) { [weak self] webView, _ in
                self?.parent.delegate?.webView(webView, didUpdateLoading: webView.isLoading)
            }
        }
    }
}

protocol MusicWebViewDelegate {
    func webViewDidCreate(_ webView: WKWebView)
    func webView(_ webView: WKWebView, didUpdateLoading isLoading: Bool)
    func webView(_ webView: WKWebView, didUpdateURL url: URL?)
    func webView(_ webView: WKWebView, didUpdateCanGoBack canGoBack: Bool)
    func webView(_ webView: WKWebView, didUpdateCanGoForward canGoForward: Bool)
}
