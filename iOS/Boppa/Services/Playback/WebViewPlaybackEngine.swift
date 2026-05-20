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

    private var hasLoadedHTML = false
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

        var artworkLocalUrl = ""
        if let remoteArtworkUrl = track.artworkUrl, !remoteArtworkUrl.isEmpty {
            if let localUrl = await ArtworkServer.shared.prefetch(from: remoteArtworkUrl) {
                artworkLocalUrl = localUrl
            }
        }

        self.setMediaSessionDetails(
            title: track.title,
            artist: track.subtitle ?? "",
            // artworkUrl: artworkLocalUrl, // TODO: Add preloading of URLs as <img>
            duration: track.duration.map { Double($0) / 1000.0 },
            playbackRate: 0.0,
            position: 0,
            playbackState: "playing"
        )

        let loadTrackScript = """
        (function() {
            try {
                var trackData = JSON.parse('\(escapedJSON)');
                if (window.boppaLoadTrack) {
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

    private func loadWebView() {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>* { margin: 0; padding: 0; } html, body, iframe { width: 100%; height: 100%; border: none; overflow: hidden; }</style>
        </head>
        <body>
            <audio id="boppa-keepalive-audio" src="\(Self.silentAudioDataURI)" loop autoplay></audio>
            <script>
                (function() {
                    var audio = document.getElementById('boppa-keepalive-audio');
                    audio.volume = 0.0001;
                    audio.playbackRate = 0.0001;
                    audio.play().catch(function(err) {});
                })();
            </script>
        </body>
        </html>
        """
        self.webView.loadHTMLString(html, baseURL: URL(string: "https://\(self.config.url)"))
        logger.info("Loaded HTML for '\(self.config.name)'")
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

            if ('mediaSession' in navigator) {
                var originalSetActionHandler = navigator.mediaSession.setActionHandler.bind(navigator.mediaSession);
                var protectedActions = new Set(['play', 'pause', 'previoustrack', 'nexttrack', 'seekbackward', 'seekforward']);

                navigator.mediaSession.setActionHandler = function(action, handler) {
                    if (protectedActions.has(action)) return;
                    originalSetActionHandler(action, handler);
                };

                originalSetActionHandler('play', function() {
                    window.webkit.messageHandlers.\(self.messageHandlerName).postMessage({type: 'playCommand'});
                });
                originalSetActionHandler('pause', function() {
                    window.webkit.messageHandlers.\(self.messageHandlerName).postMessage({type: 'pauseCommand'});
                });
                originalSetActionHandler('seekbackward', null);
                originalSetActionHandler('seekforward', null);
                originalSetActionHandler('previoustrack', function() {
                    window.webkit.messageHandlers.\(self.messageHandlerName).postMessage({type: 'previoustrackCommand'});
                });
                originalSetActionHandler('nexttrack', function() {
                    window.webkit.messageHandlers.\(self.messageHandlerName).postMessage({type: 'nexttrackCommand'});
                });

                // Intercept playbackState so media sources can't override our state
                var playbackStateDescriptor = Object.getOwnPropertyDescriptor(navigator.mediaSession.__proto__, 'playbackState')
                    || Object.getOwnPropertyDescriptor(navigator.mediaSession, 'playbackState');
                window.__boppaOriginalPlaybackStateSetter = playbackStateDescriptor && playbackStateDescriptor.set
                    ? playbackStateDescriptor.set.bind(navigator.mediaSession) : null;
                window.__boppaPlaybackState = 'paused';
                if (window.__boppaOriginalPlaybackStateSetter) {
                    window.__boppaOriginalPlaybackStateSetter.call(navigator.mediaSession, 'paused');
                    Object.defineProperty(navigator.mediaSession, 'playbackState', {
                        get: function() { return window.__boppaPlaybackState; },
                        set: function(val) {
                            // No-op: only allow changes via __boppaOriginalPlaybackStateSetter
                        },
                        configurable: true
                    });
                }

                // Intercept setPositionState so media sources can't override our position info
                window.__boppaOriginalSetPositionState = navigator.mediaSession.setPositionState.bind(navigator.mediaSession);
                window.__boppaDuration = 0;
                window.__boppaPlaybackRate = 1.0;
                window.__boppaPosition = 0;
                window.__boppaPositionTimestamp = Date.now();
                window.__boppaGetCurrentPosition = function() {
                    var elapsed = (Date.now() - window.__boppaPositionTimestamp) / 1000.0;
                    var pos = window.__boppaPosition + elapsed * window.__boppaPlaybackRate;
                    return Math.max(0, Math.min(pos, window.__boppaDuration || pos));
                };
                navigator.mediaSession.setPositionState = function(state) {
                    // No-op: only allow calls via __boppaOriginalSetPositionState
                };

                // Intercept metadata setter to maintain control over Now Playing info
                var metadataDescriptor = Object.getOwnPropertyDescriptor(navigator.mediaSession.__proto__, 'metadata')
                    || Object.getOwnPropertyDescriptor(navigator.mediaSession, 'metadata');
                var originalMetadataSetter = metadataDescriptor && metadataDescriptor.set;
                var boppaMetadata = new MediaMetadata({ title: 'Title', artist: 'Artist' });

                if (originalMetadataSetter) {
                    originalMetadataSetter.call(navigator.mediaSession, boppaMetadata);
                    Object.defineProperty(navigator.mediaSession, 'metadata', {
                        get: function() { return boppaMetadata; },
                        set: function(val) {
                            // Intercept: always set our controlled metadata via the real setter
                            originalMetadataSetter.call(navigator.mediaSession, boppaMetadata);
                        },
                        configurable: true
                    });
                } else {
                    navigator.mediaSession.metadata = boppaMetadata;
                }
            }
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
            self.play()
            return
        case "pauseCommand":
            logger.info("Received pauseCommand from webview")
            self.pause()
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
