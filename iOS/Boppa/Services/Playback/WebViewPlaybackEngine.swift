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

    private var hasLoadedHTML = false
    private var navigationContinuation: CheckedContinuation<Void, Never>?

    init(config: MediaSourceConfig) {
        self.config = config
        self.webView = WebViewFactory.makeWebView(
            scripts: config.playback.userScripts ?? [],
            contractScript: Self.contractScript(),
            customUserAgent: config.customUserAgent,
            allowsInlineMediaPlayback: true,
            isHidden: false
        )
        super.init()
        self.webView.configuration.userContentController.add(self, name: Self.messageHandlerName)
        self.webView.navigationDelegate = self
        self.attachToWindow(self.webView)
        logger.info("WebViewPlaybackEngine created for '\(config.name)'")
    }

    func load(track: Track) async -> Bool {
        if !self.hasLoadedHTML {
            self.loadWebView()
            self.hasLoadedHTML = true
            await self.waitForNavigation()
        }

        guard let escapedJSON = self.serializeTrackData(track: track) else {
            logger.error("Failed to serialize track data")
            return false
        }

        let loadTrackScript = """
        (function() {
            try {
                var trackData = JSON.parse('\(escapedJSON)');
                var frame = document.getElementById('boppa-player');
                if (frame) {
                    frame.contentWindow.postMessage({type: 'boppaLoadTrack', data: trackData}, '*');
                } else if (window.boppaLoadTrack) {
                    window.boppaLoadTrack(trackData);
                } else {
                    console.error('boppaLoadTrack not available');
                }
            } catch (e) {
                console.error('Error loading track:', e);
            }
        })();
        """

        return await withCheckedContinuation { continuation in
            self.webView.evaluateJavaScript(loadTrackScript) { _, error in
                if let error {
                    logger.error("Load track error: \(error.localizedDescription)")
                    continuation.resume(returning: false)
                } else {
                    logger.info("Sent boppaLoadTrack: \(track.title)")
                    continuation.resume(returning: true)
                }
            }
        }
    }

    private func waitForNavigation() async {
        await withCheckedContinuation { continuation in
            self.navigationContinuation = continuation
        }
    }

    private func loadWebView() {
        let html = self.config.playback.html.script
        self.webView.loadHTMLString(html, baseURL: URL(string: "https://\(self.config.url)"))
        logger.info("Loaded static HTML for '\(self.config.name)'")
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
        self.postCommandToFrame("boppaPlay")
    }

    func pause() {
        self.postCommandToFrame("boppaPause")
    }

    func seek(to timeSeconds: Double) {
        let ms = Int(timeSeconds * 1000)
        let script = """
        (function() {
            var frame = document.getElementById('boppa-player');
            if (frame) {
                frame.contentWindow.postMessage({type: 'boppaSeek', data: \(ms)}, '*');
            } else if (window.boppaSeek) {
                window.boppaSeek(\(ms));
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

    private func postCommandToFrame(_ command: String) {
        let script = """
        (function() {
            var frame = document.getElementById('boppa-player');
            if (frame) {
                frame.contentWindow.postMessage({type: '\(command)'}, '*');
            } else if (window.\(command)) {
                window.\(command)();
            }
        })();
        """
        self.webView.evaluateJavaScript(script) { _, error in
            if let error {
                logger.error("\(command) error: \(error.localizedDescription)")
            }
        }
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

            // Listen for commands from parent frame (iframe mode)
            window.addEventListener('message', function(event) {
                var msg = event.data;
                if (!msg || !msg.type) return;
                switch (msg.type) {
                    case 'boppaLoadTrack':
                        if (window.boppaLoadTrack) window.boppaLoadTrack(msg.data);
                        break;
                    case 'boppaPlay':
                        if (window.boppaPlay) window.boppaPlay();
                        break;
                    case 'boppaPause':
                        if (window.boppaPause) window.boppaPause();
                        break;
                    case 'boppaSeek':
                        if (window.boppaSeek) window.boppaSeek(msg.data);
                        break;
                }
            });
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

extension WebViewPlaybackEngine: WKNavigationDelegate {
    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            if let continuation = self.navigationContinuation {
                self.navigationContinuation = nil
                continuation.resume()
                logger.info("WebView navigation finished for '\(self.config.name)'")
            }
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            if let continuation = self.navigationContinuation {
                self.navigationContinuation = nil
                continuation.resume()
                logger.error("WebView navigation failed: \(error.localizedDescription)")
            }
        }
    }
}
