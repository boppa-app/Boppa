import Foundation
import os
import UIKit
import WebKit

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "Boppa",
    category: "WebViewFactory"
)

@MainActor
final class WebViewFactory {
    static func makeWebView(
        scripts: [Script] = [],
        contractScript: String? = nil,
        messageHandler: WKScriptMessageHandler? = nil,
        messageHandlerName: String? = nil,
        customUserAgent: String? = nil,
        allowsInlineMediaPlayback: Bool = true,
        isHidden: Bool = true
    ) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = allowsInlineMediaPlayback
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.websiteDataStore = customUserAgent != nil
            ? WebDataStore.shared.getDesktopDataStore()
            : WebDataStore.shared.getDataStore()

        let preferences = WKPreferences()
        preferences.inactiveSchedulingPolicy = .none
        configuration.preferences = preferences

        let userContentController = WKUserContentController()

        if let contractScript {
            userContentController.addUserScript(WKUserScript(
                source: contractScript,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false
            ))
        }

        for script in scripts {
            userContentController.addUserScript(WKUserScript(
                source: script.content.script,
                injectionTime: script.injectionTime.wkUserScriptInjectionTime,
                forMainFrameOnly: false
            ))
        }

        if let messageHandler, let messageHandlerName {
            userContentController.add(messageHandler, name: messageHandlerName)
        }

        configuration.userContentController = userContentController

        let screenBounds = UIScreen.main.bounds
        let webView = WKWebView(frame: screenBounds, configuration: configuration)
        webView.scrollView.isScrollEnabled = false
        webView.clipsToBounds = true
        webView.isInspectable = true
        webView.isHidden = isHidden

        self.applyUserAgent(to: webView, customUserAgent: customUserAgent)
        self.applyContentModeSize(to: webView, customUserAgent: customUserAgent)

        logger.info("Created WebView (hidden: \(isHidden), customUA: \(customUserAgent != nil))")
        return webView
    }

    private static func applyContentModeSize(to webView: WKWebView, customUserAgent: String?) {
        webView.transform = .identity

        let screenBounds = UIScreen.main.bounds

        let contentSize: CGSize
        let targetHeight: CGFloat

        if customUserAgent != nil {
            contentSize = CGSize(width: 1920, height: 1080)
            targetHeight = screenBounds.height
            logger.debug("Applying desktop content size: \(contentSize.debugDescription)")
        } else {
            contentSize = screenBounds.size
            targetHeight = screenBounds.height / 2.0
            logger.debug("Applying mobile content size: \(contentSize.debugDescription), maxHeight: \(targetHeight)")
        }

        let scale = min(screenBounds.width / contentSize.width, targetHeight / contentSize.height)
        webView.frame = CGRect(origin: .zero, size: contentSize)
        webView.transform = CGAffineTransform(scaleX: scale, y: scale)
        webView.center = CGPoint(x: screenBounds.midX, y: screenBounds.midY)
    }

    private static func applyUserAgent(to webView: WKWebView, customUserAgent: String?) {
        if let customUserAgent {
            webView.customUserAgent = customUserAgent
            webView.configuration.defaultWebpagePreferences.preferredContentMode = .desktop
            logger.debug("Applied custom user agent: \(customUserAgent)")
        } else {
            webView.customUserAgent = nil
            webView.configuration.defaultWebpagePreferences.preferredContentMode = .mobile
            logger.debug("Using default mobile content mode")
        }
    }
}
