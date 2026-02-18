import SwiftUI
import WebKit
import os


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
        let userScript = WKUserScript(
            source: visibilityScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = WebDataStore.shared.getDataStore()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.userContentController.addUserScript(userScript)

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
        
        delegate?.webViewDidCreate(webView)
        
        if let url = url {
            let request = URLRequest(url: url)
            webView.load(request)
        }
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: MusicWebView
        
        init(_ parent: MusicWebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.delegate?.webView(webView, didUpdateLoading: true)
            parent.delegate?.webView(webView, didUpdateURL: webView.url)
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.delegate?.webView(webView, didUpdateLoading: false)
            parent.delegate?.webView(webView, didUpdateCanGoBack: webView.canGoBack)
            parent.delegate?.webView(webView, didUpdateCanGoForward: webView.canGoForward)
            parent.delegate?.webView(webView, didUpdateURL: webView.url)
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.delegate?.webView(webView, didUpdateLoading: false)
            parent.delegate?.webView(webView, didUpdateCanGoBack: webView.canGoBack)
            parent.delegate?.webView(webView, didUpdateCanGoForward: webView.canGoForward)
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.delegate?.webView(webView, didUpdateLoading: false)
            parent.delegate?.webView(webView, didUpdateCanGoBack: webView.canGoBack)
            parent.delegate?.webView(webView, didUpdateCanGoForward: webView.canGoForward)
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
