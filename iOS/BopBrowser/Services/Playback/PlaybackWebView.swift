import Foundation
import os
import UIKit
import WebKit

@MainActor
final class PlaybackWebView: NSObject {
    static let shared = PlaybackWebView()

    static let messageHandlerName = "playerCallback"

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "BopBrowser",
        category: "PlaybackWebView"
    )

    private(set) var webView: WKWebView!
    private var messageDelegate: WKScriptMessageHandler?

    override private init() {
        super.init()
        self.webView = self.createWebView()
        self.attachToWindow(self.webView)
        self.logger.info("PlaybackWebView initialized")
    }

    func setMessageHandler(_ handler: WKScriptMessageHandler) {
        self.webView.configuration.userContentController.removeScriptMessageHandler(
            forName: Self.messageHandlerName
        )
        self.messageDelegate = handler
        self.webView.configuration.userContentController.add(
            handler,
            name: Self.messageHandlerName
        )
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

    private func createWebView() -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.defaultWebpagePreferences.preferredContentMode = .desktop
        configuration.userContentController.addUserScript(getDesktopScript())

        return WKWebView(
            frame: CGRect(x: -1000, y: -1000, width: 320, height: 200),
            configuration: configuration
        )
    }

    private func attachToWindow(_ webView: WKWebView) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first
            {
                window.addSubview(webView)
                self.logger.info("PlaybackWebView attached to window")
            }
        }
    }
}
