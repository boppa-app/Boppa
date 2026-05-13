import Foundation
import os
import UIKit
import WebKit

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "Boppa",
    category: "WebViewPlaybackEngine"
)

@MainActor
final class WebViewPlaybackEngine: NSObject {
    static let messageHandlerName = "playerCallback"

    var onEvent: ((PlayerEvent) -> Void)?

    private let webView: WKWebView
    private let config: MediaSourceConfig

    init(config: MediaSourceConfig) {
        self.config = config
        self.webView = WebViewFactory.makeWebView(
            scripts: config.playback.userScripts ?? [],
            contractScript: Self.contractScript(),
            customUserAgent: config.customUserAgent,
            allowsInlineMediaPlayback: true,
            isHidden: true
        )
        super.init()
        self.webView.configuration.userContentController.add(self, name: Self.messageHandlerName)
        self.attachToWindow(self.webView)
        logger.info("WebViewPlaybackEngine created for '\(config.name)'")
    }

    func load(track: Track) async -> Bool {
        guard let trackURL = track.url else {
            logger.error("Track has no URL")
            return false
        }

        guard let escapedJSON = self.serializeTrackData(track: track) else {
            logger.error("Failed to serialize track data")
            return false
        }

        let loadTrackScript = """
        (function() {
            try {
                var trackData = JSON.parse('\(escapedJSON)');
                if (window.boppaLoadTrack) {
                    window.boppaLoadTrack(trackData);
                } else {
                    console.error('boppaLoadTrack function not found');
                }
            } catch (e) {
                console.error('Error loading track:', e);
            }
        })();
        """

        let encodedTrackURL = trackURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trackURL
        let playback = self.config.playback

        if self.webView.url == nil {
            // WebView hasn't loaded anything yet — load the initial page
            return self.loadTrackIntoPage(track: track, encodedTrackURL: encodedTrackURL, playback: playback)
        }

        return await withCheckedContinuation { continuation in
            self.webView.evaluateJavaScript(loadTrackScript) { [weak self] _, error in
                guard let self else {
                    continuation.resume(returning: false)
                    return
                }

                if let error {
                    logger.error("Load track message error: \(error.localizedDescription), falling back to page reload")
                    let success = self.loadTrackIntoPage(track: track, encodedTrackURL: encodedTrackURL, playback: playback)
                    continuation.resume(returning: success)
                } else {
                    logger.info("Sent load track message: \(track.title)")
                    continuation.resume(returning: true)
                }
            }
        }
    }

    private func loadTrackIntoPage(track: Track, encodedTrackURL: String, playback: PlaybackConfig) -> Bool {
        self.webView.stopLoading()

        if let htmlTemplate = playback.html {
            let resolvedHTML = htmlTemplate.script.replacingOccurrences(of: "<TRACK_URL>", with: encodedTrackURL)
            self.webView.loadHTMLString(resolvedHTML, baseURL: URL(string: self.config.url))
            logger.info("Loading track via HTML: \(track.title)")
            return true
        } else if let urlTemplate = playback.url {
            let resolvedURLString = urlTemplate.replacingOccurrences(of: "<TRACK_URL>", with: encodedTrackURL)

            guard let url = URL(string: resolvedURLString) else {
                logger.error("Invalid playback URL: \(resolvedURLString)")
                return false
            }

            self.webView.load(URLRequest(url: url))
            logger.info("Loading track via URL: \(track.title) at \(url.absoluteString)")
            return true
        }

        logger.error("PlaybackConfig has neither 'html' nor 'url'")
        return false
    }

    private func serializeTrackData(track: Track) -> String? {
        let trackData: [String: Any] = [
            "title": track.title,
            "subtitle": track.subtitle ?? "",
            "duration": track.duration ?? 0,
            "artworkUrl": track.artworkUrl ?? "",
            "url": track.url ?? "",
            "mediaSourceId": track.mediaSourceId,
            "metadata": track.metadata,
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: trackData),
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
            if (window.boppaPlay) {
                window.boppaPlay();
            } else {
                console.error('No play function available');
            }
        })();
        """
        self.webView.evaluateJavaScript(script) { _, error in
            if let error {
                logger.error("Play command error: \(error.localizedDescription)")
            }
        }
    }

    func pause() {
        let script = """
        (function() {
            if (window.boppaPause) {
                window.boppaPause();
            } else {
                console.error('No pause function available');
            }
        })();
        """
        self.webView.evaluateJavaScript(script) { _, error in
            if let error {
                logger.error("Pause command error: \(error.localizedDescription)")
            }
        }
    }

    func seek(to timeSeconds: Double) {
        let ms = Int(timeSeconds * 1000)
        let script = """
        (function() {
            if (window.boppaSeek) {
                window.boppaSeek(\(ms));
            } else {
                console.error('No seek function available');
            }
        })();
        """
        self.webView.evaluateJavaScript(script) { _, error in
            if let error {
                logger.error("Seek command error: \(error.localizedDescription)")
            }
        }
    }

    func stop() {
        self.pause()
        logger.info("WebViewPlaybackEngine stopped")
    }

    func tearDown() {
        self.webView.stopLoading()
        self.webView.configuration.userContentController.removeAllScriptMessageHandlers()
        self.webView.removeFromSuperview()
        logger.info("WebViewPlaybackEngine torn down for '\(self.config.name)'")
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
            window.boppaPlay = null;
            window.boppaPause = null;
            window.boppaSeek = null;
            window.boppaLoadTrack = null;
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
