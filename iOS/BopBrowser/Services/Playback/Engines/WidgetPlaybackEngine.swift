import Foundation
import os
import UIKit
import WebKit

@MainActor
final class WidgetPlaybackEngine: NSObject, PlaybackEngine {
    weak var delegate: PlaybackEngineDelegate?

    private let config: WidgetPlaybackConfig
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "BopBrowser",
        category: "WidgetPlaybackEngine"
    )

    private var playbackWebView: PlaybackWebView {
        PlaybackWebView.shared
    }

    init(config: WidgetPlaybackConfig) {
        self.config = config
        super.init()
    }

    func load(track: Song) async {
        self.delegate?.engine(self, didReceiveEvent: .loading)

        guard let trackURL = track.url else {
            self.logger.error("Track has no URL, cannot load")
            self.delegate?.engine(self, didReceiveEvent: .error("Track has no URL"))
            return
        }

        guard let html = JSCodeGenerator.generateHTML(
            config: self.config,
            trackURL: trackURL,
            messageHandlerName: PlaybackWebView.messageHandlerName
        ) else {
            self.logger.error("Failed to generate safe HTML from config")
            self.delegate?.engine(self, didReceiveEvent: .error("Invalid playback config"))
            return
        }
        self.playbackWebView.setMessageHandler(self)
        self.playbackWebView.webView.navigationDelegate = self
        self.playbackWebView.loadHTML(html)
        self.logger.info("Loading widget for track: \(track.title)")
    }

    func play() {
        self.playbackWebView.evaluateJavaScript("playerPlay();") { _, error in
            if let error {
                self.logger.error("Play command error: \(error.localizedDescription)")
            }
        }
    }

    func pause() {
        self.playbackWebView.evaluateJavaScript("playerPause();") { _, error in
            if let error {
                self.logger.error("Pause command error: \(error.localizedDescription)")
            }
        }
    }

    func seek(to timeSeconds: Double) {
        let ms = Int(timeSeconds * 1000)
        self.playbackWebView.evaluateJavaScript("playerSeek(\(ms));") { _, error in
            if let error {
                self.logger.error("Seek command error: \(error.localizedDescription)")
            }
        }
    }

    func teardown() {
        self.playbackWebView.stopLoading()
    }

    private func handleMessage(_ dict: [String: Any]) {
        guard let type = dict["type"] as? String else {
            self.logger.warning("Received message without type field: \(String(describing: dict))")
            return
        }

        guard let mapping = self.config.callbackMapping[type] else {
            self.logger.debug("No callback mapping for type: \(type)")
            return
        }

        let event: PlayerEvent

        switch mapping.type {
        case "play":
            event = .playing
        case "pause":
            event = .paused
        case "progress":
            let ct = self.extractDouble(from: dict, selector: mapping.currentTime)
            let dur = self.extractDouble(from: dict, selector: mapping.duration)
            event = .progress(currentTime: ct, duration: dur)
        case "duration":
            let val = self.extractDouble(from: dict, selector: mapping.value)
            event = .durationResolved(val)
        case "finish":
            event = .finished
        case "error":
            event = .error(String(describing: dict))
        default:
            self.logger.debug("Unknown mapping type: \(mapping.type)")
            return
        }

        self.delegate?.engine(self, didReceiveEvent: event)
    }

    private func extractDouble(from dict: [String: Any], selector: String?) -> Double {
        guard let selector, !selector.isEmpty else { return 0 }
        let key = selector.hasPrefix(".") ? String(selector.dropFirst()) : selector
        let components = key.components(separatedBy: ".")

        var current: Any = dict
        for component in components {
            if let currentDict = current as? [String: Any], let next = currentDict[component] {
                current = next
            } else {
                return 0
            }
        }

        if let doubleValue = current as? Double { return doubleValue }
        if let intValue = current as? Int { return Double(intValue) }
        if let stringValue = current as? String, let parsed = Double(stringValue) { return parsed }
        return 0
    }
}

extension WidgetPlaybackEngine: WKNavigationDelegate {
    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            self.logger.debug("Widget WebView finished loading")
            self.delegate?.engine(self, didReceiveEvent: .ready)
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            self.logger.error("Widget WebView navigation failed: \(error.localizedDescription)")
            self.delegate?.engine(self, didReceiveEvent: .error(error.localizedDescription))
        }
    }
}

extension WidgetPlaybackEngine: WKScriptMessageHandler {
    nonisolated func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        let messageName = message.name
        let messageBody = message.body

        guard messageName == PlaybackWebView.messageHandlerName else { return }

        guard let dict = messageBody as? [String: Any] else {
            let bodyDesc = String(describing: messageBody)
            Task { @MainActor in
                self.logger.warning("Received non-dictionary message: \(bodyDesc)")
            }
            return
        }

        Task { @MainActor in
            self.handleMessage(dict)
        }
    }
}
