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

        self.webView = self.createWebView()
        self.webView.configuration.userContentController.add(
            messageHandler,
            name: Self.messageHandlerName
        )

        let playbackConfig = mediaSource.config.playback
        self.configureScripts(scripts: playbackConfig.scripts)
        self.applyContentMode(customUserAgent: playbackConfig.customUserAgent)

        self.applyWebViewSize(contentSize: UIScreen.main.bounds.size, maxHeight: UIScreen.main.bounds.height / 2.0)
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

    private func applyContentMode(customUserAgent: String?) {
        if let customUserAgent {
            self.webView.customUserAgent = customUserAgent
            self.webView.configuration.defaultWebpagePreferences.preferredContentMode = .desktop
            self.applyWebViewSize(contentSize: CGSize(width: 1920, height: 1080))
            logger.debug("Using desktop mode with custom user agent: \(customUserAgent)")
        } else {
            self.webView.customUserAgent = nil
            self.webView.configuration.defaultWebpagePreferences.preferredContentMode = .mobile
            self.applyWebViewSize(contentSize: UIScreen.main.bounds.size, maxHeight: UIScreen.main.bounds.height / 2.0)
            logger.debug("Using mobile mode (scaled, centered)")
        }
    }

    private func applyWebViewSize(contentSize: CGSize, maxHeight: CGFloat? = nil) {
        self.webView.transform = .identity

        let screenBounds = UIScreen.main.bounds
        let targetHeight = maxHeight ?? screenBounds.height
        let scale = min(screenBounds.width / contentSize.width, targetHeight / contentSize.height)

        self.webView.frame = CGRect(origin: .zero, size: contentSize)
        self.webView.transform = CGAffineTransform(scaleX: scale, y: scale)
        self.webView.center = CGPoint(x: screenBounds.midX, y: screenBounds.midY)
    }

    private func configureScripts(scripts: [Script]) {
        let userContentController = self.webView.configuration.userContentController

        userContentController.removeAllUserScripts()

        userContentController.addUserScript(WKUserScript(
            source: self.buildContractScript(),
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        ))

        for script in scripts {
            userContentController.addUserScript(WKUserScript(
                source: script.content.script,
                injectionTime: script.injectionTime.wkUserScriptInjectionTime,
                forMainFrameOnly: false
            ))
        }
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

    private func createWebView() -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.websiteDataStore = WebDataStore.shared.getDataStore()

        let webView = WKWebView(
            frame: UIScreen.main.bounds,
            configuration: configuration
        )
        webView.scrollView.isScrollEnabled = false
        webView.clipsToBounds = true
        webView.isInspectable = true
        webView.isHidden = true
        // webView.isHidden = false
        return webView
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
