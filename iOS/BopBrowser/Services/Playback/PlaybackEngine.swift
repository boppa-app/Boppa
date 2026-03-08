import Foundation
import os
import SwiftData
import WebKit

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "BopBrowser",
    category: "PlaybackEngine"
)

@MainActor
final class PlaybackEngine: NSObject {
    static let shared = PlaybackEngine()

    var onEvent: ((PlayerEvent) -> Void)?

    private var webViews: [String: PlaybackWebView] = [:]
    private var mediaSources: [MediaSource] = []
    private var activeMediaSource: MediaSource?
    private var modelContext: ModelContext?
    private var mediaSourceAddedObserver: NSObjectProtocol?
    private var mediaSourceRemovedObserver: NSObjectProtocol?

    override private init() {
        super.init()
        self.observeMediaSourceChanges()
    }

    func startMonitoring(modelContainer: ModelContainer) {
        self.modelContext = ModelContext(modelContainer)

        let descriptor = FetchDescriptor<MediaSource>()
        let sources = (try? self.modelContext?.fetch(descriptor)) ?? []

        for source in sources {
            let webView = PlaybackWebView(mediaSource: source, messageHandler: self)
            self.webViews[source.name] = webView
            logger.info("Created PlaybackWebView for source: \(source.name)")
        }

        self.mediaSources = sources
        logger.info("Initial setup complete: \(self.webViews.count) web view(s) active")
    }

    func load(track: Song, mediaSourceName: String) async {
        self.onEvent?(.loading)

        guard let trackURL = track.url else {
            logger.error("Track has no URL, cannot load")
            self.onEvent?(.error("Track has no URL"))
            return
        }

        guard let webView = self.webViews[mediaSourceName] else {
            logger.error("No PlaybackWebView for source: \(mediaSourceName)")
            self.onEvent?(.error("No playback web view configured for \(mediaSourceName)"))
            return
        }

        guard let mediaSource = self.mediaSources.first(where: { $0.name == mediaSourceName }) else {
            logger.error("No MediaSource found for source: \(mediaSourceName)")
            self.onEvent?(.error("No media source for \(mediaSourceName)"))
            return
        }

        let config = mediaSource.config.playback
        self.activeMediaSource = mediaSource

        let encodedTrackURL = trackURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trackURL

        if let htmlTemplate = config.html {
            let resolvedHTML = htmlTemplate.script.replacingOccurrences(of: "<TRACK_URL>", with: encodedTrackURL)
            webView.loadHTML(resolvedHTML)
            logger.info("Loading track via HTML: \(track.title)")
        } else if let urlTemplate = config.url {
            let resolvedURLString = urlTemplate.replacingOccurrences(of: "<TRACK_URL>", with: encodedTrackURL)

            guard let url = URL(string: resolvedURLString) else {
                logger.error("Invalid playback URL: \(resolvedURLString)")
                self.onEvent?(.error("Invalid playback URL"))
                return
            }

            webView.loadURL(url)
            logger.info("Loading track via URL: \(track.title) at \(url.absoluteString)")
        } else {
            logger.error("PlaybackConfig has neither 'url' nor 'html'")
            self.onEvent?(.error("No playback URL or HTML configured"))
        }
    }

    func play() {
        guard let webView = self.activeWebView else { return }
        webView.evaluateJavaScript("playerPlay();") { _, error in
            if let error {
                logger.error("Play command error: \(error.localizedDescription)")
            }
        }
    }

    func pause() {
        guard let webView = self.activeWebView else { return }
        webView.evaluateJavaScript("playerPause();") { _, error in
            if let error {
                logger.error("Pause command error: \(error.localizedDescription)")
            }
        }
    }

    func seek(to timeSeconds: Double) {
        guard let webView = self.activeWebView else { return }
        let ms = Int(timeSeconds * 1000)
        webView.evaluateJavaScript("playerSeek(\(ms));") { _, error in
            if let error {
                logger.error("Seek command error: \(error.localizedDescription)")
            }
        }
    }

    func teardown() {
        guard let webView = self.activeWebView else { return }
        webView.stopLoading()
    }

    private var activeWebView: PlaybackWebView? {
        guard let source = self.activeMediaSource else {
            logger.warning("No active media source set")
            return nil
        }
        return self.webViews[source.name]
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

    private func observeMediaSourceChanges() {
        self.mediaSourceAddedObserver = NotificationCenter.default.addObserver(
            forName: .mediaSourceAdded,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                guard let self,
                      let names = notification.userInfo?["names"] as? [String]
                else { return }
                self.handleSourcesAdded(names: names)
            }
        }

        self.mediaSourceRemovedObserver = NotificationCenter.default.addObserver(
            forName: .mediaSourceRemoved,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                guard let self,
                      let names = notification.userInfo?["names"] as? [String]
                else { return }
                self.handleSourcesRemoved(names: names)
            }
        }
    }

    private func handleSourcesAdded(names: [String]) {
        guard let modelContext else { return }

        let descriptor = FetchDescriptor<MediaSource>()
        guard let sources = try? modelContext.fetch(descriptor) else { return }

        for source in sources where names.contains(source.name) {
            let webView = PlaybackWebView(mediaSource: source, messageHandler: self)
            self.webViews[source.name] = webView
            self.mediaSources.append(source)
            logger.info("Added PlaybackWebView for source: \(source.name)")
        }
    }

    private func handleSourcesRemoved(names: [String]) {
        for name in names {
            if let webView = self.webViews.removeValue(forKey: name) {
                webView.teardown()
                logger.info("Removed PlaybackWebView for source: \(name)")
            }
            self.mediaSources.removeAll { $0.name == name }
            if self.activeMediaSource?.name == name {
                self.activeMediaSource = nil
            }
        }
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
