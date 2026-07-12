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

    private var isReady = false
    private var pendingTrack: Track?

    init(config: MediaSourceConfig) {
        self.config = config
        self.webView = WebViewFactory.makeWebView(
            scripts: config.playback.userScripts,
            contractScript: Self.contractScript(),
            customUserAgent: config.playback.customUserAgent,
            allowsInlineMediaPlayback: true,
            isHidden: true
        )
        super.init()
        self.webView.configuration.userContentController.add(self, name: Self.messageHandlerName)
        self.webView.navigationDelegate = self
        self.attachToWindow(self.webView)
        if let playbackUrl = config.playback.url {
            self.webView.load(URLRequest(url: URL(string: playbackUrl)!))
        } else if let html = config.playback.html {
            self.webView.loadHTMLString(html, baseURL: URL(string: "https://\(config.url)"))
        }
        logger.info("WebViewPlaybackEngine created for '\(config.name)'")
    }

    func load(track: Track) {
        guard self.isReady else {
            logger.info("WebView not ready yet, deferring boppaLoad for '\(track.title)'")
            self.pendingTrack = track
            return
        }
        self.performLoad(track: track)
    }

    private func performLoad(track: Track) {
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

    private func handleNavigationFinished() {
        self.isReady = true
        logger.info("WebView ready for '\(self.config.name)'")

        if let pendingTrack {
            self.pendingTrack = nil
            self.performLoad(track: pendingTrack)
        }
    }

    private func serializeTrackData(track: Track) -> String? {
        let metadata = track.metadata.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]
        let trackData: [String: Any] = [
            "title": track.title,
            "subtitle": track.subtitle ?? "",
            "duration": track.duration ?? 0,
            "lowResArtworkUrl": ArtworkURLBridge.localURLString(for: track.lowResArtworkUrl),
            "highResArtworkUrl": ArtworkURLBridge.localURLString(for: track.highResArtworkUrl),
            "url": track.url ?? "",
            "mediaSourceId": track.mediaSourceId,
            "metadata": metadata,
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

    // TODO: See why play to resume via widget is quiet sometimes (after inactivity) and requires sequential play/pause/play taps
    func play() {
        let script = """
        (function() {
            if (window.boppaPlay) window.boppaPlay();
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
            if (window.boppaPause) window.boppaPause();
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
        self.pendingTrack = nil

        let script = """
        (function() {
            if (window.boppaStop) window.boppaStop();
        })();
        """
        self.webView.evaluateJavaScript(script) { _, error in
            if let error { logger.error("Stop command error: \(error.localizedDescription)") }
        }
        logger.info("WebViewPlaybackEngine stopped")
    }

    func preloadArtwork(urls: [String]) {
        guard !urls.isEmpty else { return }
        let calls = urls.compactMap { url -> String? in
            guard !url.isEmpty else { return nil }
            let localURLString = ArtworkURLBridge.localURLString(for: url)
            guard !localURLString.isEmpty else { return nil }
            let id = Self.artworkElementId(for: url)
            let escapedUrl = localURLString
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

    private func reloadPlayback() {
        self.isReady = false
        if let url = self.config.playback.url {
            self.webView.load(URLRequest(url: URL(string: url)!))
        } else if let html = self.config.playback.html {
            self.webView.loadHTMLString(html, baseURL: URL(string: "https://\(self.config.url)"))
        }
    }

    private static func contractScript() -> String {
        """
        (function() {
            window.postEvent = function(eventObj) {
                window.webkit.messageHandlers.\(self.messageHandlerName).postMessage(eventObj);
            };
            window.boppaPopup = function(id) {
                window.webkit.messageHandlers.\(self.messageHandlerName).postMessage({ type: 'popup', id: id });
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
        case "popup":
            let id = dict["id"] as? String ?? ""
            guard let popupConfig = self.config.popup?[id] else {
                logger.warning("No popup config found for id '\(id)'")
                return
            }
            PlaybackService.shared.stop()
            PopupManager.shared.showPopup(
                config: popupConfig,
                onDismiss: { [weak self] in self?.reloadPlayback() }
            )
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
            self.handleNavigationFinished()
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            logger.error("WebView navigation failed for '\(self.config.name)': \(error.localizedDescription)")
            self.handleNavigationFinished()
        }
    }

    nonisolated func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        Task { @MainActor in
            logger.error("WebView provisional navigation failed for '\(self.config.name)': \(error.localizedDescription)")
            self.handleNavigationFinished()
        }
    }
}
