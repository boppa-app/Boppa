import Foundation
import Combine
import WebKit

@Observable
class BrowserViewModel: MusicWebViewDelegate {
    var currentURL: URL?
    var isLoading: Bool = false
    var canGoBack: Bool = false
    var canGoForward: Bool = false
    
    private weak var webView: WKWebView?

    init() {
    }
    
    func webViewDidCreate(_ webView: WKWebView) {
        self.webView = webView
    }
    
    func webView(_ webView: WKWebView, didUpdateLoading isLoading: Bool) {
        self.isLoading = isLoading
    }
    
    func webView(_ webView: WKWebView, didUpdateURL url: URL?) {
        self.currentURL = url
    }
    
    func webView(_ webView: WKWebView, didUpdateCanGoBack canGoBack: Bool) {
        self.canGoBack = canGoBack
    }
    
    func webView(_ webView: WKWebView, didUpdateCanGoForward canGoForward: Bool) {
        self.canGoForward = canGoForward
    }

    func loadURL(urlString: String) {
        var urlToLoad = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !urlToLoad.hasPrefix("http://") && !urlToLoad.hasPrefix("https://") {
            urlToLoad = "https://" + urlToLoad
        }
        if let url = URL(string: urlToLoad) {
            currentURL = url
            let request = URLRequest(url: url)
            webView?.load(request)
        }
    }
    
    func goBack() {
        webView?.goBack()
    }
    
    func goForward() {
        webView?.goForward()
    }
    
    func refresh() {
        webView?.reload()
    }
    
    func stop() {
        webView?.stopLoading()
    }
}
