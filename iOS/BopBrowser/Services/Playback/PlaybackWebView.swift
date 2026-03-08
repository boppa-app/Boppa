import Foundation
import os
import UIKit
import WebKit

// TODO: Add functionality to fetch + store scripts

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "BopBrowser",
    category: "PlaybackWebView"
)

@MainActor
final class PlaybackWebView: NSObject {
    static let messageHandlerName = "playerCallback"

    private(set) var webView: WKWebView!
    let mediaSourceName: String

    init(mediaSource: MediaSource, messageHandler: WKScriptMessageHandler) {
        self.mediaSourceName = mediaSource.name
        super.init()

        let config = mediaSource.config
        let playbackConfig = config.playback

        self.webView = WebViewFactory.makeWebView(
            scripts: playbackConfig.scripts,
            contractScript: self.buildContractScript(),
            messageHandler: messageHandler,
            messageHandlerName: Self.messageHandlerName,
            customUserAgent: config.customUserAgent,
            allowsInlineMediaPlayback: true,
            isHidden: true
        )

        self.attachToWindow(self.webView)
        logger.info("PlaybackWebView created for media source: \(mediaSource.name)")
    }

    func loadURL(_ url: URL) {
        logger.info("Loading URL: \(url.absoluteString)")
        self.webView.load(URLRequest(url: url))
    }

    func loadHTML(_ html: String) {
        self.webView.loadHTMLString(html, baseURL: nil)
    }

    func evaluateJavaScript(_ script: String, completion: ((Any?, Error?) -> Void)? = nil) {
        self.webView.evaluateJavaScript(script, completionHandler: completion)
    }

    func stopLoading() {
        self.webView.stopLoading()
    }

    func teardown() {
        self.webView.stopLoading()
        self.webView.removeFromSuperview()
        logger.info("PlaybackWebView torn down for media source: \(self.mediaSourceName)")
    }

    private func buildContractScript() -> String {
        """
        (function() {
            window.postEvent = function(eventObj) {
                window.webkit.messageHandlers.\(Self.messageHandlerName).postMessage(eventObj);
            };
        })();
        """
    }

    private func attachToWindow(_ webView: WKWebView) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first
            {
                window.addSubview(webView)
                logger.info("PlaybackWebView attached to window for source: \(self.mediaSourceName)")
            }
        }
    }
}
