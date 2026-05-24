import Foundation
import os
import UIKit
import WebKit

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "Boppa",
    category: "WebViewPlaybackEngine"
)

private extension UInt16 {
    var littleEndianBytes: Data {
        var value = self.littleEndian
        return Data(bytes: &value, count: MemoryLayout<UInt16>.size)
    }
}

private extension UInt32 {
    var littleEndianBytes: Data {
        var value = self.littleEndian
        return Data(bytes: &value, count: MemoryLayout<UInt32>.size)
    }
}

private extension Int16 {
    var littleEndianBytes: Data {
        var value = self.littleEndian
        return Data(bytes: &value, count: MemoryLayout<Int16>.size)
    }
}

@MainActor
final class WebViewPlaybackEngine: NSObject {
    static let messageHandlerName = "playerCallback"

    var onEvent: ((PlayerEvent) -> Void)?

    private let webView: WKWebView
    private let config: MediaSourceConfig

    private var navigationContinuation: CheckedContinuation<Void, Never>?

    private static let silentAudioDataURI: String = generateSilentWAVDataURI()

    init(config: MediaSourceConfig) {
        self.config = config
        self.webView = WebViewFactory.makeWebView(
            scripts: config.playback.userScripts,
            contractScript: Self.contractScript(),
            customUserAgent: config.customUserAgent,
            allowsInlineMediaPlayback: true,
            isHidden: false
        )
        super.init()
        self.webView.configuration.userContentController.add(self, name: Self.messageHandlerName)
        self.webView.configuration.userContentController.addUserScript(
            getMediaSessionInterceptScript(messageHandlerName: Self.messageHandlerName)
        )
        self.attachToWindow(self.webView)
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>* { margin: 0; padding: 0; } html, body, iframe { width: 100%; height: 100%; border: none; overflow: hidden; }</style>
        </head>
        <body>
            <audio id="boppa-keepalive-audio" src="\(Self.silentAudioDataURI)" muted loop></audio>
            <script>
                (function() {
                    var audio = document.getElementById('boppa-keepalive-audio');
                    audio.volume = 0.0001;
                    audio.playbackRate = 0.0001;
                })();
            </script>
        </body>
        </html>
        """
        self.webView.loadHTMLString(html, baseURL: URL(string: "https://\(config.url)"))
        logger.info("WebViewPlaybackEngine created for '\(config.name)'")
    }

    func load(track: Track, shouldRestartKeepalive: Bool = false) async -> Bool {
        guard let escapedJSON = self.serializeTrackData(track: track) else {
            logger.error("Failed to serialize track data")
            return false
        }

        let loadTrackScript = """
        (function() {
            try {
                var trackData = JSON.parse('\(escapedJSON)');
                if (window.boppaLoad) {
                    window.boppaLoad(trackData);
                } else {
                    console.error('boppaLoad not available');
                }
                var audio = document.getElementById('boppa-keepalive-audio');
                if (audio) {
                    if (\(shouldRestartKeepalive)) {
                        audio.pause();
                        setTimeout(function() { audio.play().catch(function(e){}); }, 100);
                    } else {
                        audio.play();
                    }
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
                    logger.info("Sent boppaLoad: \(track.title)")
                    continuation.resume(returning: true)
                }
            }
        }
    }

    func setNowPlayingInfo(track: Track) {
        self.setMediaSessionDetails(
            title: track.title,
            artist: track.subtitle ?? "",
            artworkUrl: ArtworkServer.localURL(for: track.artworkUrl) ?? "",
            duration: track.duration.map { Double($0) / 1000.0 },
            playbackRate: 0.0,
            position: 0,
            playbackState: "playing"
        )
    }

    func activateNowPlayingInfo() {
        let script = """
        (function() {
            var audio = document.getElementById('boppa-keepalive-audio');
            if (!audio) return;
            audio.__boppaPauseHandler = function() {
                window.webkit.messageHandlers.\(Self.messageHandlerName).postMessage({type: 'playCommand'});
            };
            audio.__boppaPlayHandler = function() {
                window.webkit.messageHandlers.\(Self.messageHandlerName).postMessage({type: 'pauseCommand'});
            };
            audio.addEventListener('pause', audio.__boppaPauseHandler);
            audio.addEventListener('play', audio.__boppaPlayHandler);
            document.getElementById('boppa-keepalive-audio').muted = false;
        })();
        """
        self.webView.evaluateJavaScript(script) { _, error in
            if let error { logger.error("activateNowPlayingInfo error: \(error.localizedDescription)") }
        }
    }

    func deactivateNowPlayingInfo() {
        let script = """
        (function() {
            var audio = document.getElementById('boppa-keepalive-audio');
            if (!audio) return;
            if (audio.__boppaPauseHandler) {
                audio.removeEventListener('pause', audio.__boppaPauseHandler);
                delete audio.__boppaPauseHandler;
            }
            if (audio.__boppaPlayHandler) {
                audio.removeEventListener('play', audio.__boppaPlayHandler);
                delete audio.__boppaPlayHandler;
            }
            document.getElementById('boppa-keepalive-audio').muted = true;
        })();
        """
        self.webView.evaluateJavaScript(script) { _, error in
            if let error { logger.error("deactivateNowPlayingInfo error: \(error.localizedDescription)") }
        }
    }

    private func setMediaSessionDetails(
        title: String? = nil,
        artist: String? = nil,
        artworkUrl: String? = nil,
        duration: Double? = nil,
        playbackRate: Double? = nil,
        position: Double? = nil,
        playbackState: String? = nil
    ) {
        var scriptParts: [String] = []
        scriptParts.append("if (!('mediaSession' in navigator)) return;")

        if let playbackState {
            scriptParts.append("""
            window.__boppaPlaybackState = '\(playbackState)';
            if (window.__boppaOriginalPlaybackStateSetter) {
                window.__boppaOriginalPlaybackStateSetter.call(navigator.mediaSession, '\(playbackState)');
            }
            """)
        }

        if title != nil || artist != nil || artworkUrl != nil {
            let escapedTitle = (title ?? "")
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
            let escapedArtist = (artist ?? "")
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
            let escapedArtworkUrl = (artworkUrl ?? "")
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")

            scriptParts.append("""
            var metadataInit = {
                title: '\(escapedTitle)',
                artist: '\(escapedArtist)'
            };
            if ('\(escapedArtworkUrl)') {
                metadataInit.artwork = [{ src: '\(escapedArtworkUrl)' }];
            }
            var newMetadata = new MediaMetadata(metadataInit);

            var desc = Object.getOwnPropertyDescriptor(navigator.mediaSession, 'metadata');
            if (desc && desc.set) {
                var originalSetter = Object.getOwnPropertyDescriptor(
                    navigator.mediaSession.__proto__, 'metadata'
                );
                if (originalSetter && originalSetter.set) {
                    originalSetter.set.call(navigator.mediaSession, newMetadata);
                }
                Object.defineProperty(navigator.mediaSession, 'metadata', {
                    get: function() { return newMetadata; },
                    set: function(val) {
                        if (originalSetter && originalSetter.set) {
                            originalSetter.set.call(navigator.mediaSession, newMetadata);
                        }
                    },
                    configurable: true
                });
            } else {
                navigator.mediaSession.metadata = newMetadata;
            }
            """)
        }

        if duration != nil || playbackRate != nil || position != nil {
            var updates: [String] = []
            if let duration {
                updates.append("window.__boppaDuration = \(duration);")
            }
            if let playbackRate {
                updates.append("window.__boppaPlaybackRate = \(playbackRate);")
            }
            if let position {
                updates.append("window.__boppaPosition = \(position);")
            }

            scriptParts.append("""
            var currentPos = window.__boppaGetCurrentPosition ? window.__boppaGetCurrentPosition() : 0;
            \(updates.joined(separator: "\n"))
            if (window.__boppaOriginalSetPositionState && window.__boppaDuration > 0) {
                try {
                    var pos = \(position != nil ? "Math.min(window.__boppaPosition, window.__boppaDuration)" : "Math.min(currentPos, window.__boppaDuration)");
                    window.__boppaPosition = pos;
                    window.__boppaPositionTimestamp = Date.now();
                    window.__boppaOriginalSetPositionState.call(navigator.mediaSession, {
                        duration: window.__boppaDuration,
                        playbackRate: window.__boppaPlaybackRate ?? 1.0,
                        position: pos
                    });
                } catch (e) {}
            }
            """)
        }

        let script = "(function() { \(scriptParts.joined(separator: "\n")) })();"

        self.webView.evaluateJavaScript(script) { _, error in
            if let error {
                logger.error("Set media session details error: \(error.localizedDescription)")
            }
        }
    }

    private func waitForNavigation() async {
        await withCheckedContinuation { continuation in
            self.navigationContinuation = continuation
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
            if (window.boppaPlay) window.boppaPlay();
            var audio = document.getElementById('boppa-keepalive-audio');
            if (audio && audio.paused) audio.play();
        })();
        """
        self.webView.evaluateJavaScript(script) { _, error in
            if let error {
                logger.error("Play command error: \(error.localizedDescription)")
            }
        }
        self.setMediaSessionDetails(playbackRate: 1.0, playbackState: "playing")
    }

    func pause() {
        let script = """
        (function() {
            if (window.boppaPause) window.boppaPause();
            // DO NOT PAUSE KEEP ALIVE HERE (messes with position, NowPlayingInfo)
        })();
        """
        self.webView.evaluateJavaScript(script) { _, error in
            if let error {
                logger.error("Pause command error: \(error.localizedDescription)")
            }
        }
        self.setMediaSessionDetails(playbackRate: 0.0001, playbackState: "paused")
    }

    func seek(to timeSeconds: Double) {
        let ms = Int(timeSeconds * 1000)
        let script = "if (window.boppaSeek) window.boppaSeek(\(ms));"
        self.webView.evaluateJavaScript(script) { _, error in
            if let error {
                logger.error("Seek command error: \(error.localizedDescription)")
            }
        }
        self.setMediaSessionDetails(position: timeSeconds)
    }

    func stop() {
        self.pause()
        logger.info("WebViewPlaybackEngine stopped")
    }

    func preloadArtwork(urls: [String]) {
        guard !urls.isEmpty else { return }
        let escapedUrls = urls.compactMap { url -> String? in
            guard !url.isEmpty else { return nil }
            return url
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
        }
        guard !escapedUrls.isEmpty else { return }

        let calls = escapedUrls.map { "window.__boppaPreloadArtwork('\($0)');" }.joined(separator: "\n")
        let script = "(function() { \(calls) })();"
        self.webView.evaluateJavaScript(script) { _, error in
            if let error {
                logger.error("Preload artwork error: \(error.localizedDescription)")
            }
        }
    }

    func removeArtwork(urls: [String]) {
        guard !urls.isEmpty else { return }
        let escapedUrls = urls.compactMap { url -> String? in
            guard !url.isEmpty else { return nil }
            return url
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
        }
        guard !escapedUrls.isEmpty else { return }

        let calls = escapedUrls.map { "window.__boppaRemoveArtwork('\($0)');" }.joined(separator: "\n")
        let script = "(function() { \(calls) })();"
        self.webView.evaluateJavaScript(script) { _, error in
            if let error {
                logger.error("Remove artwork error: \(error.localizedDescription)")
            }
        }
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
                PlaybackService.shared.previous()
            }
            return
        case "nexttrackCommand":
            logger.info("Received nexttrackCommand from webview")
            Task { @MainActor in
                PlaybackService.shared.next()
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
            self.setMediaSessionDetails(playbackRate: 1.0)
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

    private static func generateSilentWAVDataURI() -> String {
        let sampleRate: UInt32 = 44100
        let duration: UInt32 = 1
        let numSamples = sampleRate * duration
        let dataSize = numSamples * 2 // 16-bit = 2 bytes per sample

        var wavData = Data()

        // WAV header
        wavData.append("RIFF".data(using: .ascii)!)
        wavData.append(UInt32(36 + dataSize).littleEndianBytes)
        wavData.append("WAVE".data(using: .ascii)!)
        wavData.append("fmt ".data(using: .ascii)!)
        wavData.append(UInt32(16).littleEndianBytes) // PCM
        wavData.append(UInt16(1).littleEndianBytes) // AudioFormat (PCM)
        wavData.append(UInt16(1).littleEndianBytes) // NumChannels (mono)
        wavData.append(sampleRate.littleEndianBytes)
        wavData.append((sampleRate * 2).littleEndianBytes) // ByteRate
        wavData.append(UInt16(2).littleEndianBytes) // BlockAlign
        wavData.append(UInt16(16).littleEndianBytes) // BitsPerSample
        wavData.append("data".data(using: .ascii)!)
        wavData.append(dataSize.littleEndianBytes)

        // Audio data: near-silence (very low amplitude sine wave at 20Hz)
        for i in 0 ..< numSamples {
            let t = Double(i) / Double(sampleRate)
            let sample = Int16(sin(2.0 * .pi * 20.0 * t) * 3.0)
            wavData.append(sample.littleEndianBytes)
        }

        let base64 = wavData.base64EncodedString()
        return "data:audio/wav;base64,\(base64)"
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
