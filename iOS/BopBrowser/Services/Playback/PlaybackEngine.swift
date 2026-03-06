import Foundation
import os
import WebKit

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "BopBrowser",
    category: "PlaybackEngine"
)

@MainActor
final class PlaybackEngine: NSObject {
    static let shared = PlaybackEngine()

    var onEvent: ((PlayerEvent) -> Void)?

    private var playbackWebView: PlaybackWebView {
        PlaybackWebView.shared
    }

    override private init() {
        super.init()
    }

    func load(track: Song, config: PlaybackConfig, mediaSource: MediaSource) async {
        self.onEvent?(.loading)

        guard let trackURL = track.url else {
            logger.error("Track has no URL, cannot load")
            self.onEvent?(.error("Track has no URL"))
            return
        }

        self.playbackWebView.configureForMediaSource(mediaSource)

        let encodedTrackURL = trackURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trackURL

        if let htmlTemplate = config.html {
            let resolvedHTML = htmlTemplate.script.replacingOccurrences(of: "<TRACK_URL>", with: encodedTrackURL)
            self.playbackWebView.loadHTML(resolvedHTML)
            logger.info("Loading track via HTML: \(track.title)")
        } else if let urlTemplate = config.url {
            let resolvedURLString = urlTemplate.replacingOccurrences(of: "<TRACK_URL>", with: encodedTrackURL)

            guard let url = URL(string: resolvedURLString) else {
                logger.error("Invalid playback URL: \(resolvedURLString)")
                self.onEvent?(.error("Invalid playback URL"))
                return
            }

            self.playbackWebView.loadURL(url)
            logger.info("Loading track via URL: \(track.title) at \(url.absoluteString)")
        } else {
            logger.error("PlaybackConfig has neither 'url' nor 'html'")
            self.onEvent?(.error("No playback URL or HTML configured"))
        }
    }

    func play() {
        self.playbackWebView.evaluateJavaScript("playerPlay();") { _, error in
            if let error {
                logger.error("Play command error: \(error.localizedDescription)")
            }
        }
    }

    func pause() {
        self.playbackWebView.evaluateJavaScript("playerPause();") { _, error in
            if let error {
                logger.error("Pause command error: \(error.localizedDescription)")
            }
        }
    }

    func seek(to timeSeconds: Double) {
        let ms = Int(timeSeconds * 1000)
        self.playbackWebView.evaluateJavaScript("playerSeek(\(ms));") { _, error in
            if let error {
                logger.error("Seek command error: \(error.localizedDescription)")
            }
        }
    }

    func teardown() {
        self.playbackWebView.stopLoading()
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

extension PlaybackEngine: WKScriptMessageHandler {
    nonisolated func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == PlaybackWebView.messageHandlerName else { return }

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
