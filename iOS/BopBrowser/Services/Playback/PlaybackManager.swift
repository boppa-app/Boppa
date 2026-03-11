import Foundation
import os

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "BopBrowser",
    category: "PlaybackManager"
)

@MainActor
final class PlaybackManager {
    static let shared = PlaybackManager()

    var onEvent: ((PlayerEvent) -> Void)?

    private var activeEngine: PlaybackEngine?

    private let avPlayerEngine = AVPlayerPlaybackEngine.shared
    private let webViewEngine = WebViewPlaybackEngine.shared

    private init() {}

    func load(track: Song, mediaSource: MediaSource) async {
        self.onEvent?(.loading)

        let config = mediaSource.config
        let playback = config.playback

        self.activeEngine?.stop()
        self.activeEngine = nil

        if playback.streamUrl != nil {
            self.avPlayerEngine.onEvent = { [weak self] event in self?.onEvent?(event) }
            if await self.avPlayerEngine.load(track: track, config: config) {
                self.activeEngine = self.avPlayerEngine
                logger.info("Loaded '\(track.title)' via AVPlayerPlaybackEngine")
                return
            }
            self.avPlayerEngine.stop()
            logger.warning("AVPlayerPlaybackEngine failed for '\(track.title)', trying WebView...")
        }

        if playback.html != nil || playback.url != nil {
            self.webViewEngine.onEvent = { [weak self] event in self?.onEvent?(event) }
            if await self.webViewEngine.load(track: track, config: config) {
                self.activeEngine = self.webViewEngine
                logger.info("Loaded '\(track.title)' via WebViewPlaybackEngine")
                return
            }
            self.webViewEngine.stop()
        }

        logger.error("All playback methods failed for track: \(track.title)")
        self.onEvent?(.error("No playback method succeeded"))
    }

    func play() {
        self.activeEngine?.play()
    }

    func pause() {
        self.activeEngine?.pause()
    }

    func seek(to timeSeconds: Double) {
        self.activeEngine?.seek(to: timeSeconds)
    }

    func stop() {
        self.activeEngine?.stop()
        self.activeEngine = nil
    }
}
