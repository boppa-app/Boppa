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

    private var navigationContinuation: CheckedContinuation<Void, Never>?

    init(config: MediaSourceConfig) {
        self.config = config
        self.webView = WebViewFactory.makeWebView(
            scripts: config.playback.userScripts,
            contractScript: Self.contractScript(),
            customUserAgent: config.customUserAgent,
            allowsInlineMediaPlayback: true,
            isHidden: true
        )
        super.init()
        self.webView.configuration.userContentController.add(self, name: Self.messageHandlerName)
        self.attachToWindow(self.webView)
        if let playbackUrl = config.playback.url {
            self.webView.load(URLRequest(url: URL(string: playbackUrl)!))
        } else if let html = config.playback.html {
            self.webView.loadHTMLString(html, baseURL: URL(string: "https://\(config.url)"))
        }
        logger.info("WebViewPlaybackEngine created for '\(config.name)'")
    }

    func load(track: Track) {
        guard let escapedJSON = self.serializeTrackData(track: track) else {
            logger.error("Failed to serialize track data")
            return
        }

        let script = """
        (function() {
            try {
                var trackData = JSON.parse('\(escapedJSON)');
                if (window.boppaLoad) {
                    window.boppaLoad(trackData);
                } else {
                    console.error('boppaLoad not available');
                }
            } catch (e) {
                console.error('Error loading track:', e);
            }
        })();
        """

        self.webView.evaluateJavaScript(script) { _, error in
            if let error { logger.error("Load track error: \(error.localizedDescription)") }
        }
    }

    func activateNowPlayingInfo() {
        let script = "window.postMessage({type: 'boppaActivateKeepalive'}, '*');"
        self.webView.evaluateJavaScript(script) { _, error in
            if let error { logger.error("activateNowPlayingInfo error: \(error.localizedDescription)") }
        }
    }

    func deactivateNowPlayingInfo() {
        let script = "window.postMessage({type: 'boppaDeactivateKeepalive'}, '*');"
        self.webView.evaluateJavaScript(script) { _, error in
            if let error { logger.error("deactivateNowPlayingInfo error: \(error.localizedDescription)") }
        }
    }

    private func serializeTrackData(track: Track) -> String? {
        let trackData: [String: Any] = [
            "title": track.title,
            "subtitle": track.subtitle ?? "",
            "duration": track.duration ?? 0,
            "artworkUrl": track.artworkUrl ?? "",
            "url": track.url ?? "",
            "mediaSourceId": track.mediaSourceId,
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

    // TODO: Evaluate if this is necessary, see why play to resume via widget is quiet
    // sometimes (after inactivity) and requires sequential play/pause/play taps
    func play() {
        let script = """
        (function() {
            if (window.boppaMute) window.boppaMute();
            if (window.boppaPause) window.boppaPause();
            if (window.boppaPlay) window.boppaPlay();
            if (window.boppaPause) window.boppaPause();
            if (window.boppaPlay) window.boppaPlay();
            if (window.boppaUnmute) window.boppaUnmute();
            window.postMessage({type: 'boppaActivateKeepalive'}, '*');
        })();
        """
        self.webView.evaluateJavaScript(script) { _, error in
            if let error {
                logger.error("Play command error: \(error.localizedDescription)")
            }
        }
    }

    func pause(shouldPauseKeepAlive: Bool? = true) {
        let script = """
        (function() {
            if (window.boppaPause) window.boppaPause();
            if (\((shouldPauseKeepAlive ?? true) ? "true" : "false")) {
                window.postMessage({type: 'boppaDeactivateKeepalive'}, '*');
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
        let script = "if (window.boppaSeek) window.boppaSeek(\(ms));"
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

    func preloadArtwork(urls: [String]) {
        guard !urls.isEmpty else { return }
        let calls = urls.compactMap { url -> String? in
            guard !url.isEmpty else { return nil }
            let id = Self.artworkElementId(for: url)
            let escapedUrl = url
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
            return """
            (function() {
                if (document.getElementById('\(id)')) return;
                var img = document.createElement('img');
                img.id = '\(id)';
                img.src = '\(escapedUrl)';
                img.style.cssText = 'position:absolute;width:1px;height:1px;opacity:0;pointer-events:none;';
                document.body.appendChild(img);
            })();
            """
        }
        guard !calls.isEmpty else { return }
        self.webView.evaluateJavaScript(calls.joined(separator: "\n")) { _, error in
            if let error {
                logger.error("Preload artwork error: \(error.localizedDescription)")
            }
        }
    }

    func removeArtwork(urls: [String]) {
        guard !urls.isEmpty else { return }
        let calls = urls.compactMap { url -> String? in
            guard !url.isEmpty else { return nil }
            let id = Self.artworkElementId(for: url)
            return "var el = document.getElementById('\(id)'); if (el) el.remove();"
        }
        guard !calls.isEmpty else { return }
        self.webView.evaluateJavaScript(calls.joined(separator: "\n")) { _, error in
            if let error {
                logger.error("Remove artwork error: \(error.localizedDescription)")
            }
        }
    }

    private static func artworkElementId(for url: String) -> String {
        var hash: Int32 = 0
        for char in url.unicodeScalars {
            hash = (hash &<< 5) &- hash &+ Int32(char.value)
        }
        return "boppa-artwork-\(String(abs(hash), radix: 36))"
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
        case "playCommand":
            logger.info("Received playCommand from webview")
            PlaybackService.shared.play()
            return
        case "pauseCommand":
            logger.info("Received pauseCommand from webview")
            PlaybackService.shared.pause()
            return
        case "previoustrackCommand":
            logger.info("Received previoustrackCommand from webview")
            Task { @MainActor in
                PlaybackService.shared.previous(userInitiated: true)
            }
            return
        case "nexttrackCommand":
            logger.info("Received nexttrackCommand from webview")
            Task { @MainActor in
                PlaybackService.shared.next(userInitiated: true)
            }
            return
        case "seekCommand":
            let seekTime = self.extractDouble(from: dict, key: "seekTime")
            logger.info("Received seekCommand from webview: \(seekTime)s")
            PlaybackService.shared.seek(to: seekTime)
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
