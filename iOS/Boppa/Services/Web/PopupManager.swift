import Foundation
import os
import WebKit

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "Boppa",
    category: "PopupManager"
)

struct PopupPresentation: Identifiable {
    let id = UUID()
    let title: String
    let webView: WKWebView
}

@Observable
final class PopupManager: NSObject {
    static let shared = PopupManager()

    static let messageHandlerName = "boppaPopupMessage"

    private(set) var activePopup: PopupPresentation?
    private var onDismiss: (() -> Void)?

    override private init() {
        super.init()
    }

    @MainActor
    func showPopup(config: PopupConfig, onDismiss: @escaping () -> Void) {
        guard self.activePopup == nil else {
            logger.warning("Popup already presented, ignoring request for '\(config.title)'")
            return
        }

        self.onDismiss = onDismiss

        let webView = WebViewFactory.makeWebView(
            scripts: config.userScripts,
            contractScript: Self.contractScript(),
            messageHandler: self,
            messageHandlerName: Self.messageHandlerName,
            customUserAgent: config.customUserAgent,
            isHidden: false
        )
        webView.transform = .identity
        webView.frame = .zero
        webView.scrollView.isScrollEnabled = true
        webView.allowsBackForwardNavigationGestures = true

        if let url = URL(string: config.url) {
            webView.load(URLRequest(url: url))
        }

        self.activePopup = PopupPresentation(title: config.title, webView: webView)
        logger.info("Popup presented: '\(config.title)'")
    }

    @MainActor
    func dismiss() {
        guard let popup = self.activePopup else { return }
        self.tearDownWebView(popup.webView)
        self.activePopup = nil
        let handler = self.onDismiss
        self.onDismiss = nil
        handler?()
    }

    @MainActor
    private func tearDownWebView(_ webView: WKWebView) {
        webView.stopLoading()
        webView.configuration.userContentController.removeScriptMessageHandler(forName: Self.messageHandlerName)
    }

    static func contractScript() -> String {
        """
        (function() {
            window.boppaPopupDismiss = function() {
                window.webkit.messageHandlers.\(self.messageHandlerName).postMessage({ type: 'dismiss' });
            };
        })();
        """
    }
}

extension PopupManager: WKScriptMessageHandler {
    nonisolated func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == Self.messageHandlerName,
              let body = message.body as? [String: Any],
              let type = body["type"] as? String
        else { return }

        Task { @MainActor in
            switch type {
            case "dismiss":
                logger.info("boppaPopupDismiss called from JS")
                self.dismiss()
            default:
                logger.warning("Unknown popup message type: \(type)")
            }
        }
    }
}
