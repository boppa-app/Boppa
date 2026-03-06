import Foundation
import os
import SwiftData
import UIKit
import WebKit

// TODO: Add functionality to fetch + store scripts

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "BopBrowser",
    category: "PlaybackWebView"
)

@MainActor
final class PlaybackWebView: NSObject {
    static let shared = PlaybackWebView()

    static let messageHandlerName = "playerCallback"

    private(set) var webView: WKWebView!
    private var configuredSourceName: String?

    private var mediaSourceObserver: NSObjectProtocol?

    override private init() {
        super.init()
        self.webView = self.createWebView()
        self.webView.configuration.userContentController.add(
            PlaybackEngine.shared,
            name: Self.messageHandlerName
        )
        self.configureScripts(scripts: [])
        self.applyWebViewSize(contentSize: UIScreen.main.bounds.size, maxHeight: UIScreen.main.bounds.height / 2.0)
        self.attachToWindow(self.webView)
        self.observeMediaSourceChanges()
        logger.info("PlaybackWebView initialized")
    }

    func resetConfiguration() {
        self.configuredSourceName = nil
        self.configureScripts(scripts: [])
        logger.info("PlaybackWebView configuration reset")
    }

    func configureForMediaSource(_ mediaSource: MediaSource) {
        guard mediaSource.name != self.configuredSourceName else { return }

        guard let config = mediaSource.config,
              let playbackConfig = config.playback
        else {
            logger.warning("No playback config for source: \(mediaSource.name)")
            return
        }

        self.configureScripts(scripts: playbackConfig.scripts)
        self.applyContentMode(customUserAgent: playbackConfig.customUserAgent)
        self.configuredSourceName = mediaSource.name
        logger.info("Configured scripts for media source: \(mediaSource.name)")
    }

    func configureForPrimarySource(modelContainer: ModelContainer) {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<MediaSource>()
        guard let sources = try? context.fetch(descriptor),
              let primary = sources.first
        else {
            logger.info("No primary media source found")
            return
        }

        self.configureForMediaSource(primary)
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
                logger.info("PlaybackWebView attached to window")
            }
        }
    }

    private func observeMediaSourceChanges() {
        self.mediaSourceObserver = NotificationCenter.default.addObserver(
            forName: .mediaSourcesDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.resetConfiguration()
            }
        }
    }
}
