import Foundation
import os
import UIKit
import WebKit

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "BopBrowser",
    category: "WebViewPlaybackEngine"
)

// TODO: Integration with seek and prev/next is broken, total track time also broken (seems like its only when switching mid track)
// TODO: Keep paused state when executing prev/next

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
        if self.webView == nil || self.needsReconfigure(for: config) {
            self.reconfigureWebView(config: config)
            return self.loadTrackIntoPage(track: track, config: config)
        }

        guard let webView = self.webView else {
            logger.error("WebView not available")
            return false
        }

        guard let escapedJSON: String = self.seralizeSongData(track: track) else {
            logger.error("Failed to serialize track data")
            return false
        }
        // Post message to webview to load new track
        let loadTrackScript = """
        (function() {
            try {
                var trackData = JSON.parse('\(escapedJSON)');
                if (window.bopBrowserLoadTrack) {
                    window.bopBrowserLoadTrack(trackData);
                } else {
                    console.error('bopBrowserLoadTrack function not found');
                }
            } catch (e) {
                console.error('Error loading track:', e);
            }
        })();
        """

        return await withCheckedContinuation { continuation in
            webView.evaluateJavaScript(loadTrackScript) { [weak self] _, error in
                guard let self else {
                    continuation.resume(returning: false)
                    return
                }

                if let error {
                    logger.error("Load track message error: \(error.localizedDescription), falling back to page reload")
                    let success = self.loadTrackIntoPage(track: track, config: config)
                    continuation.resume(returning: success)
                } else {
                    logger.info("Sent load track message: \(track.title)")
                    continuation.resume(returning: true)
                }
            }
        }
    }

    private func loadTrackIntoPage(track: Song, config: MediaSourceConfig) -> Bool {
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
        let playback = config.playback

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

    private func seralizeSongData(track: Song) -> String? {
        let songData: [String: Any] = [
            "title": track.title,
            "artist": track.artist ?? "",
            "duration": track.duration ?? 0,
            "artworkUrl": track.artworkUrl ?? "",
            "url": track.url ?? "",
            "mediaSourceName": track.mediaSourceName ?? "",
            "metadata": track.metadata,
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: songData),
              let jsonString = String(data: jsonData, encoding: .utf8)
        else {
            return nil
        }

        return jsonString
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
    }

    func play() {
        let script = """
        (function() {
            if (window.bopBrowserPlay) {
                window.bopBrowserPlay();
            } else {
                console.error('No play function available');
            }
        })();
        """
        self.webView?.evaluateJavaScript(script) { _, error in
            if let error {
                logger.error("Play command error: \(error.localizedDescription)")
            }
        }
    }

    func pause() {
        let script = """
        (function() {
            if (window.bopBrowserPause) {
                window.bopBrowserPause();
            } else {
                console.error('No pause function available');
            }
        })();
        """
        self.webView?.evaluateJavaScript(script) { _, error in
            if let error {
                logger.error("Pause command error: \(error.localizedDescription)")
            }
        }
    }

    func seek(to timeSeconds: Double) {
        let ms = Int(timeSeconds * 1000)
        let script = """
        (function() {
            if (window.bopBrowserSeek) {
                window.bopBrowserSeek(\(ms));
            } else {
                console.error('No seek function available');
            }
        })();
        """
        self.webView?.evaluateJavaScript(script) { _, error in
            if let error {
                logger.error("Seek command error: \(error.localizedDescription)")
            }
        }
    }

    func stop() {
        self.pause()
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
            // Post events back to Swift
            window.postEvent = function(eventObj) {
                window.webkit.messageHandlers.\(self.messageHandlerName).postMessage(eventObj);
            };
            
            // Placeholder functions for play/pause/seek/loadTrack
            // User scripts must define these functions to handle playback control
            window.bopBrowserPlay = null;
            window.bopBrowserPause = null;
            window.bopBrowserSeek = null;
            window.bopBrowserLoadTrack = null;
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

        switch type {
        case "previoustrack":
            logger.info("Received previoustrack message from webview")
            Task { @MainActor in
                PlaybackService.shared.previous()
            }
            return
        case "nexttrack":
            logger.info("Received nexttrack message from webview")
            Task { @MainActor in
                PlaybackService.shared.next()
            }
            return
        default:
            break
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
