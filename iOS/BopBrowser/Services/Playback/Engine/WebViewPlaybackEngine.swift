import Foundation
import os
import UIKit
import WebKit

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "BopBrowser",
    category: "WebViewPlaybackEngine"
)

@MainActor
final class WebViewPlaybackEngine: NSObject, PlaybackEngine {
    static let shared = WebViewPlaybackEngine()
    static let messageHandlerName = "playerCallback"

    var onEvent: ((PlayerEvent) -> Void)?

    private var webView: WKWebView?
    private var currentConfigName: String?
    private var lastWebViewUpdatedTime: Date?

    override private init() {
        super.init()
    }

    func load(track: Song, config: MediaSourceConfig) async -> Bool {
        let playback = config.playback

        if self.webView == nil || self.needsReconfigure(for: config) {
            self.reconfigureWebView(config: config)
        }

        guard let webView = self.webView else {
            logger.error("Failed to create web view")
            return false
        }

        guard let trackURL = track.url else {
            logger.error("Track has no URL")
            return false
        }

        webView.stopLoading()

        let encodedTrackURL = trackURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trackURL

        if let htmlTemplate = playback.html {
            let resolvedHTML = htmlTemplate.script.replacingOccurrences(of: "<TRACK_URL>", with: encodedTrackURL)
            webView.loadHTMLString(resolvedHTML, baseURL: nil)
            logger.info("Loading track via HTML: \(track.title)")
            return true
        } else if let urlTemplate = playback.url {
            let resolvedURLString = urlTemplate.replacingOccurrences(of: "<TRACK_URL>", with: encodedTrackURL)

            guard let url = URL(string: resolvedURLString) else {
                logger.error("Invalid playback URL: \(resolvedURLString)")
                return false
            }

            webView.load(URLRequest(url: url))
            logger.info("Loading track via URL: \(track.title) at \(url.absoluteString)")
            return true
        }

        logger.error("PlaybackConfig has neither 'html' nor 'url'")
        return false
    }

    func play() {
        self.webView?.evaluateJavaScript("playerPlay();") { _, error in
            if let error {
                logger.error("Play command error: \(error.localizedDescription)")
            }
        }
    }

    func pause() {
        self.webView?.evaluateJavaScript("playerPause();") { _, error in
            if let error {
                logger.error("Pause command error: \(error.localizedDescription)")
            }
        }
    }

    func seek(to timeSeconds: Double) {
        let ms = Int(timeSeconds * 1000)
        self.webView?.evaluateJavaScript("playerSeek(\(ms));") { _, error in
            if let error {
                logger.error("Seek command error: \(error.localizedDescription)")
            }
        }
    }

    func stop() {
        self.webView?.loadHTMLString("", baseURL: nil)
        logger.info("WebViewPlaybackEngine stopped")
    }

    private func needsReconfigure(for config: MediaSourceConfig) -> Bool {
        if self.currentConfigName != config.name {
            return true
        }
        if let webViewUpdated = self.lastWebViewUpdatedTime,
           config.lastUpdated > webViewUpdated
        {
            return true
        }
        return false
    }

    private func reconfigureWebView(config: MediaSourceConfig) {
        if let oldWebView = self.webView {
            oldWebView.stopLoading()
            oldWebView.configuration.userContentController.removeAllScriptMessageHandlers()
            oldWebView.removeFromSuperview()
        }

        let webView = WebViewFactory.makeWebView(
            scripts: config.playback.userScripts,
            contractScript: Self.contractScript(),
            customUserAgent: config.customUserAgent,
            allowsInlineMediaPlayback: true,
            isHidden: true
        )

        webView.configuration.userContentController.add(self, name: Self.messageHandlerName)

        self.webView = webView
        self.currentConfigName = config.name
        self.lastWebViewUpdatedTime = Date()

        self.attachToWindow(webView)

        logger.info("WebViewPlaybackEngine reconfigured for '\(config.name)'")
    }

    private static func contractScript() -> String {
        """
        (function() {
            window.postEvent = function(eventObj) {
                window.webkit.messageHandlers.\(self.messageHandlerName).postMessage(eventObj);
            };
        })();
        """
    }

    private func attachToWindow(_ webView: WKWebView) {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first
        {
            window.addSubview(webView)
            logger.info("WebViewPlaybackEngine attached to window")
        }
    }

    private func handleMessage(_ dict: [String: Any]) {
        guard let type = dict["type"] as? String else {
            logger.warning("Received message without type: \(String(describing: dict))")
            return
        }

        let event: PlayerEvent

        switch type {
        case "play", "initialPlay":
            event = .playing
        case "pause":
            event = .paused
        case "progress":
            let currentTime = self.extractDouble(from: dict, key: "currentTime")
            let duration = self.extractDouble(from: dict, key: "duration")
            event = .progress(currentTime: currentTime, duration: duration)
        case "duration":
            let value = self.extractDouble(from: dict, key: "value")
            event = .durationResolved(value)
        case "finish":
            event = .finished
        case "error":
            let message = dict["message"] as? String ?? "Unknown playback error"
            event = .error(message)
        default:
            logger.debug("Unknown event type: \(type)")
            return
        }

        self.onEvent?(event)
    }

    private func extractDouble(from dict: [String: Any], key: String) -> Double {
        if let doubleValue = dict[key] as? Double { return doubleValue }
        if let intValue = dict[key] as? Int { return Double(intValue) }
        if let stringValue = dict[key] as? String, let parsed = Double(stringValue) { return parsed }
        return 0
    }
}

extension WebViewPlaybackEngine: WKScriptMessageHandler {
    nonisolated func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == Self.messageHandlerName else { return }

        guard let dict = message.body as? [String: Any] else {
            let bodyDesc = String(describing: message.body)
            Task { @MainActor in
                logger.warning("Received non-dictionary message: \(bodyDesc)")
            }
            return
        }

        Task { @MainActor in
            self.handleMessage(dict)
        }
    }
}
