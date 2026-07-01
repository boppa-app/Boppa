import Foundation
import os
import SwiftUI
import UIKit
import WebKit

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "Boppa",
    category: "PopupManager"
)

@Observable
final class PopupManager: NSObject {
    static let shared = PopupManager()

    static let messageHandlerName = "boppaPopupMessage"

    private var hostingController: UIViewController?
    private var popupWebView: WKWebView?
    private var onDismiss: (() -> Void)?
    private var isDismissing = false

    override private init() {
        super.init()
    }

    @MainActor
    func showPopup(config: PopupConfig, customUserAgent: String?, onDismiss: @escaping () -> Void) {
        guard self.hostingController == nil else {
            logger.warning("Popup already presented, ignoring request for '\(config.title)'")
            return
        }

        self.onDismiss = onDismiss
        self.isDismissing = false

        let webView = WebViewFactory.makeWebView(
            scripts: config.userScripts,
            contractScript: Self.contractScript(),
            messageHandler: self,
            messageHandlerName: Self.messageHandlerName,
            customUserAgent: customUserAgent,
            isHidden: false
        )
        webView.transform = .identity
        webView.frame = .zero
        webView.scrollView.isScrollEnabled = true
        webView.allowsBackForwardNavigationGestures = true
        self.popupWebView = webView

        if let url = URL(string: config.url) {
            webView.load(URLRequest(url: url))
        }

        let sheetView = PopupSheetView(title: config.title, webView: webView) { [weak self] in
            self?.dismissFromButton()
        } onDisappeared: { [weak self] in
            self?.onPopupDisappeared()
        }

        let hostVC = UIHostingController(rootView: sheetView)
        self.hostingController = hostVC

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first
        else { return }

        var presenter = window.rootViewController
        while let next = presenter?.presentedViewController {
            presenter = next
        }
        presenter?.present(hostVC, animated: true)

        logger.info("Popup presented: '\(config.title)'")
    }

    @MainActor
    func dismiss() {
        guard let hostVC = self.hostingController, !self.isDismissing else { return }
        self.isDismissing = true
        hostVC.dismiss(animated: true)
    }

    @MainActor
    private func dismissFromButton() {
        self.dismiss()
    }

    @MainActor
    private func onPopupDisappeared() {
        self.isDismissing = false
        self.hostingController = nil
        self.tearDownWebView()
        let handler = self.onDismiss
        self.onDismiss = nil
        handler?()
    }

    @MainActor
    private func tearDownWebView() {
        if let webView = self.popupWebView {
            webView.stopLoading()
            webView.configuration.userContentController.removeScriptMessageHandler(forName: Self.messageHandlerName)
        }
        self.popupWebView = nil
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

private struct PopupSheetView: View {
    let title: String
    let webView: WKWebView
    let onDone: () -> Void
    let onDisappeared: () -> Void

    var body: some View {
        NavigationStack {
            PopupWebViewRepresentable(webView: self.webView)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(self.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text(self.title)
                            .fontWeight(.semibold)
                    }
                    .sharedBackgroundVisibilityIfAvailable(.hidden)
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: self.onDone) {
                            Image(systemName: "door.left.hand.open")
                                .foregroundColor(Color.purp)
                        }
                    }
                    .sharedBackgroundVisibilityIfAvailable(.hidden)
                }
        }
        .onDisappear {
            self.onDisappeared()
        }
    }
}

private struct PopupWebViewRepresentable: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView {
        self.webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
