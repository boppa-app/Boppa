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

    private func waitForNavigation() async {
        await withCheckedContinuation { continuation in
            self.navigationContinuation = continuation
        }
    }

    private func loadWebView() {
        let bodyContent = self.config.playback.bodyHtml.script
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
                    audio.volume = 0.001;
                    audio.play().catch(function(err) {});
                })();
            </script>
            \(bodyContent)
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
            var audio = document.getElementById('boppa-keepalive-audio');
            if (audio) audio.play().catch(function(e){});
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
            var audio = document.getElementById('boppa-keepalive-audio');
            if (audio) audio.pause();
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
                var protectedActions = new Set(['previoustrack', 'nexttrack', 'seekbackward', 'seekforward']);

                navigator.mediaSession.setActionHandler = function(action, handler) {
                    if (protectedActions.has(action)) return;
                    originalSetActionHandler(action, handler);
                };

                originalSetActionHandler('play', function() {
                    // var ka = document.getElementById('boppa-keepalive-audio');
                    // if (ka) ka.play().catch(function(e){});
                    if (window.boppaPlay) window.boppaPlay();
                });
                originalSetActionHandler('pause', function() {
                    // var ka = document.getElementById('boppa-keepalive-audio');
                    // if (ka) ka.pause();
                    if (window.boppaPause) window.boppaPause();
                });
                originalSetActionHandler('seekbackward', null);
                originalSetActionHandler('seekforward', null);
                originalSetActionHandler('previoustrack', function() {
                    window.webkit.messageHandlers.\(self.messageHandlerName).postMessage({type: 'previoustrack'});
                });
                originalSetActionHandler('nexttrack', function() {
                    window.webkit.messageHandlers.\(self.messageHandlerName).postMessage({type: 'nexttrack'});
                });

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
