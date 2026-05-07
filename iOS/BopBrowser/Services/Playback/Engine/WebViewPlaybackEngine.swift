import Foundation
import os
import UIKit
import WebKit

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "BopBrowser",
    category: "WebViewPlaybackEngine"
)

// MARK: - Little-endian byte helpers for WAV generation

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

// TODO: Integration with seek and prev/next is broken, total track time also broken (seems like its only when switching mid track)
// TODO: Keep paused state when executing prev/next
// TODO: Add support for triggering pop-up with webview by posting a message back to Swift

@MainActor
final class WebViewPlaybackEngine: NSObject, PlaybackEngine {
    static let shared = WebViewPlaybackEngine()
    static let messageHandlerName = "playerCallback"

    var onEvent: ((PlayerEvent) -> Void)?

    private var webView: WKWebView?
    private var currentConfigName: String?
    private var lastWebViewUpdatedTime: Date?

    /// Tracks whether the persistent iframe page (with silent audio) has been loaded
    private var iframePageLoaded = false

    /// Cached silent WAV data URI (generated once)
    private lazy var silentAudioDataURI: String = Self.generateSilentWAVDataURI()

    override private init() {
        super.init()
    }

    func load(playbackSource: PlaybackSource) async -> Bool {
        switch playbackSource {
        case let .track(track, config):
            if self.webView == nil || self.needsReconfigure(for: config) {
                self.reconfigureWebView(config: config)
                self.iframePageLoaded = false
                return self.loadTrackIntoPage(track: track, config: config)
            }

            // For iframe-based playback, update only the iframe src and metadata
            if config.playback.url != nil, self.iframePageLoaded {
                return self.updateIframeAndMetadata(track: track, config: config)
            }

            // For iframe-based playback on first load
            if config.playback.url != nil {
                return self.loadTrackIntoPage(track: track, config: config)
            }

            guard let webView = self.webView else {
                logger.error("WebView not available")
                return false
            }

            guard let escapedJSON: String = self.seralizeTrackData(track: track) else {
                logger.error("Failed to serialize track data")
                return false
            }

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
        case .getTrackResponse:
            logger.error("WebViewPlaybackEngine does not support loading from GetTrackResponse")
            return false
        }
    }

    /// Updates only the iframe src and mediaSession metadata without destroying the page.
    /// This preserves the silent audio element and its AudioSession.
    private func updateIframeAndMetadata(track: Track, config: MediaSourceConfig) -> Bool {
        guard let webView = self.webView else {
            logger.error("WebView not available for iframe update")
            return false
        }

        guard let trackURL = track.url else {
            logger.error("Track has no URL")
            return false
        }

        let encodedTrackURL = trackURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trackURL

        guard let urlTemplate = config.playback.url else {
            logger.error("Config has no URL template")
            return false
        }

        let resolvedURLString = urlTemplate.replacingOccurrences(of: "<TRACK_URL>", with: encodedTrackURL)
        let title = Self.escapeForJS(track.title)
        let artist = Self.escapeForJS(track.subtitle ?? "Unknown Artist")
        let artworkUrl = Self.escapeForJS(track.artworkUrl ?? "")
        let duration = Double(track.duration ?? 0) / 1000.0

        let script = """
        (function() {
            // Update iframe src
            var iframe = document.getElementById('bopBrowserIframe');
            if (iframe) {
                iframe.src = '\(Self.escapeForJS(resolvedURLString))';
            }

            // Update mediaSession metadata
            if ('mediaSession' in navigator) {
                navigator.mediaSession.metadata = new MediaMetadata({
                    title: '\(title)',
                    artist: '\(artist)',
                    album: '',
                    artwork: [
                        { src: '\(artworkUrl)', sizes: '512x512', type: 'image/jpeg' }
                    ]
                });

                if ('setPositionState' in navigator.mediaSession) {
                    try {
                        navigator.mediaSession.setPositionState({
                            duration: \(duration),
                            playbackRate: 1.0,
                            position: 0
                        });
                    } catch (e) {}
                }

                navigator.mediaSession.playbackState = 'playing';
            }
        })();
        """

        webView.evaluateJavaScript(script) { _, error in
            if let error {
                logger.error("Failed to update iframe and metadata: \(error.localizedDescription)")
            }
        }

        logger.info("Updated iframe src and metadata for: \(track.title) at \(resolvedURLString)")
        return true
    }

    private func loadTrackIntoPage(track: Track, config: MediaSourceConfig) -> Bool {
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
            self.iframePageLoaded = false
            logger.info("Loading track via HTML: \(track.title)")
            return true
        } else if let urlTemplate = playback.url {
            let resolvedURLString = urlTemplate.replacingOccurrences(of: "<TRACK_URL>", with: encodedTrackURL)
            let title = Self.escapeForJS(track.title)
            let artist = Self.escapeForJS(track.subtitle ?? "Unknown Artist")
            let artworkUrl = Self.escapeForJS(track.artworkUrl ?? "")
            let duration = Double(track.duration ?? 0) / 1000.0

            let iframeHTML = """
            <!DOCTYPE html>
            <html>
            <head>
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <style>
                    * { margin: 0; padding: 0; }
                    html, body { width: 100%; height: 100%; overflow: hidden; }
                    iframe { width: 100%; height: 100%; border: none; }
                </style>
            </head>
            <body>
                <audio id="bopBrowserKeepaliveAudio" src="\(self.silentAudioDataURI)" loop autoplay></audio>
                <iframe id="bopBrowserIframe" src="\(resolvedURLString)" allow="autoplay; encrypted-media" allowfullscreen></iframe>
                <script>
                    (function() {
                        'use strict';

                        var audio = document.getElementById('bopBrowserKeepaliveAudio');
                        audio.volume = 0.001;

                        // Ensure audio keeps playing to maintain AudioSession
                        audio.addEventListener('pause', function() {
                            audio.play().catch(function(err) {});
                        });

                        if ('mediaSession' in navigator) {
                            navigator.mediaSession.metadata = new MediaMetadata({
                                title: '\(title)',
                                artist: '\(artist)',
                                album: '',
                                artwork: [
                                    { src: '\(artworkUrl)', sizes: '512x512', type: 'image/jpeg' }
                                ]
                            });

                            if ('setPositionState' in navigator.mediaSession) {
                                try {
                                    navigator.mediaSession.setPositionState({
                                        duration: \(duration),
                                        playbackRate: 1.0,
                                        position: 0
                                    });
                                } catch (e) {}
                            }

                            navigator.mediaSession.playbackState = 'playing';

                            // Wire mediaSession controls to iframe playback (NOT the silent audio)
                            navigator.mediaSession.setActionHandler('play', function() {
                                if (window.bopBrowserPlay) {
                                    window.bopBrowserPlay();
                                } else {
                                    var iframe = document.getElementById('bopBrowserIframe');
                                    if (iframe && iframe.contentWindow) {
                                        iframe.contentWindow.postMessage({ type: 'bopBrowser', command: 'play' }, '*');
                                    }
                                }
                                window.webkit.messageHandlers.\(Self.messageHandlerName).postMessage({type: 'mediaSessionPlay'});
                            });
                            navigator.mediaSession.setActionHandler('pause', function() {
                                if (window.bopBrowserPause) {
                                    window.bopBrowserPause();
                                } else {
                                    var iframe = document.getElementById('bopBrowserIframe');
                                    if (iframe && iframe.contentWindow) {
                                        iframe.contentWindow.postMessage({ type: 'bopBrowser', command: 'pause' }, '*');
                                    }
                                }
                                window.webkit.messageHandlers.\(Self.messageHandlerName).postMessage({type: 'mediaSessionPause'});
                            });
                            navigator.mediaSession.setActionHandler('previoustrack', function() {
                                window.webkit.messageHandlers.\(Self.messageHandlerName).postMessage({type: 'previoustrack'});
                            });
                            navigator.mediaSession.setActionHandler('nexttrack', function() {
                                window.webkit.messageHandlers.\(Self.messageHandlerName).postMessage({type: 'nexttrack'});
                            });
                        }

                        audio.play().catch(function(err) {});
                    })();
                </script>
            </body>
            </html>
            """

            webView.loadHTMLString(iframeHTML, baseURL: URL(string: resolvedURLString))
            self.iframePageLoaded = true
            logger.info("Loading track via iframe URL with keepalive audio: \(track.title) at \(resolvedURLString)")
            return true
        }

        logger.error("PlaybackConfig has neither 'html' nor 'url'")
        return false
    }

    private func seralizeTrackData(track: Track) -> String? {
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
            if (window.bopBrowserPlay) {
                window.bopBrowserPlay();
            } else {
                var iframe = document.getElementById('bopBrowserIframe') || document.querySelector('iframe');
                if (iframe && iframe.contentWindow) {
                    iframe.contentWindow.postMessage({ type: 'bopBrowser', command: 'play' }, '*');
                } else {
                    console.error('No play function available');
                }
            }
            // Update mediaSession playback state
            if ('mediaSession' in navigator) {
                navigator.mediaSession.playbackState = 'playing';
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
                var iframe = document.getElementById('bopBrowserIframe') || document.querySelector('iframe');
                if (iframe && iframe.contentWindow) {
                    iframe.contentWindow.postMessage({ type: 'bopBrowser', command: 'pause' }, '*');
                } else {
                    console.error('No pause function available');
                }
            }
            // Update mediaSession playback state
            if ('mediaSession' in navigator) {
                navigator.mediaSession.playbackState = 'paused';
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
                var iframe = document.getElementById('bopBrowserIframe') || document.querySelector('iframe');
                if (iframe && iframe.contentWindow) {
                    iframe.contentWindow.postMessage({ type: 'bopBrowser', command: 'seek', value: \(ms) }, '*');
                } else {
                    console.error('No seek function available');
                }
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
            scripts: config.playback.userScripts ?? [],
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

            // Listen for commands from parent frame (when running inside an iframe)
            window.addEventListener('message', function(event) {
                if (!event.data || event.data.type !== 'bopBrowser') return;
                var command = event.data.command;
                if (command === 'play' && window.bopBrowserPlay) {
                    window.bopBrowserPlay();
                } else if (command === 'pause' && window.bopBrowserPause) {
                    window.bopBrowserPause();
                } else if (command === 'seek' && window.bopBrowserSeek) {
                    window.bopBrowserSeek(event.data.value);
                } else if (command === 'loadTrack' && window.bopBrowserLoadTrack) {
                    window.bopBrowserLoadTrack(event.data.trackData);
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
        case "mediaSessionPlay":
            logger.info("Received mediaSession play action")
            Task { @MainActor in
                PlaybackService.shared.play()
            }
            return
        case "mediaSessionPause":
            logger.info("Received mediaSession pause action")
            Task { @MainActor in
                PlaybackService.shared.pause()
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

    // MARK: - Silent WAV Generation

    /// Generates a 10-second silent WAV file as a data URI for keeping the AudioSession alive
    private static func generateSilentWAVDataURI() -> String {
        let sampleRate: UInt32 = 44100
        let duration: UInt32 = 10 // 10 seconds
        let numSamples = sampleRate * duration
        let dataSize = numSamples * 2 // 16-bit = 2 bytes per sample

        var wavData = Data()

        // WAV header
        wavData.append("RIFF".data(using: .ascii)!) // ChunkID
        wavData.append(UInt32(36 + dataSize).littleEndianBytes) // ChunkSize
        wavData.append("WAVE".data(using: .ascii)!) // Format
        wavData.append("fmt ".data(using: .ascii)!) // Subchunk1ID
        wavData.append(UInt32(16).littleEndianBytes) // Subchunk1Size (PCM)
        wavData.append(UInt16(1).littleEndianBytes) // AudioFormat (PCM)
        wavData.append(UInt16(1).littleEndianBytes) // NumChannels (mono)
        wavData.append(sampleRate.littleEndianBytes) // SampleRate
        wavData.append((sampleRate * 2).littleEndianBytes) // ByteRate
        wavData.append(UInt16(2).littleEndianBytes) // BlockAlign
        wavData.append(UInt16(16).littleEndianBytes) // BitsPerSample
        wavData.append("data".data(using: .ascii)!) // Subchunk2ID
        wavData.append(dataSize.littleEndianBytes) // Subchunk2Size

        // Audio data: near-silence (very low amplitude sine wave at 20Hz)
        for i in 0 ..< numSamples {
            let t = Double(i) / Double(sampleRate)
            let sample = Int16(sin(2.0 * .pi * 20.0 * t) * 3.0) // Very low amplitude
            wavData.append(sample.littleEndianBytes)
        }

        // Convert to base64 data URI
        let base64 = wavData.base64EncodedString()
        return "data:audio/wav;base64,\(base64)"
    }

    // MARK: - JS String Escaping

    private static func escapeForJS(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
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
