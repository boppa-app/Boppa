import Foundation
import os

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "Boppa",
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

    // TODO: On failure show pop-up with error details
    func load(track: Track, mediaSource: MediaSource) async {
        self.onEvent?(.loading)

        let playback = mediaSource.config.playback

        self.activeEngine?.stop()
        self.activeEngine = nil

        let streamPlaying = await self.tryStreamPlayback(playbackMode: playback.mode, track: track, mediaSource: mediaSource, fallback: false)
        if streamPlaying { return }
        let webPlaying = await self.tryWebPlayback(playbackMode: playback.mode, track: track, mediaSource: mediaSource, fallback: false)
        if webPlaying { return }
        let streamFallbackPlaying = await self.tryStreamPlayback(playbackMode: playback.mode, track: track, mediaSource: mediaSource, fallback: true)
        if streamFallbackPlaying { return }
        let webFallbackPlaying = await self.tryWebPlayback(playbackMode: playback.mode, track: track, mediaSource: mediaSource, fallback: true)
        if webFallbackPlaying { return }

        logger.error("All playback methods failed for track: \(track.title)")
        self.onEvent?(.error("No playback method succeeded"))
    }

    private func tryStreamPlayback(playbackMode: PlaybackMode, track: Track, mediaSource: MediaSource, fallback: Bool) async -> Bool {
        if playbackMode == .streamOnly || (playbackMode == .webFallback && fallback) {
            let getTrackResponse = await self.getTrack(track: track, mediaSource: mediaSource)
            if let getTrackResponse = getTrackResponse {
                self.avPlayerEngine.onEvent = { [weak self] event in self?.onEvent?(event) }
                if await self.avPlayerEngine.load(getTrackResponse: getTrackResponse) {
                    self.activeEngine = self.avPlayerEngine
                    logger.info("Loaded '\(track.title)' via AVPlayerPlaybackEngine")
                    return true
                }
                self.avPlayerEngine.stop()
                logger.warning("AVPlayerPlaybackEngine failed for '\(track.title)', trying WebView...")
            }
        }
        return false
    }

    private func tryWebPlayback(playbackMode: PlaybackMode, track: Track, mediaSource: MediaSource, fallback: Bool) async -> Bool {
        let config = mediaSource.config
        if playbackMode == .webOnly || (playbackMode == .streamFallback && fallback) {
            if config.playback.html != nil || config.playback.url != nil {
                self.webViewEngine.onEvent = { [weak self] event in self?.onEvent?(event) }
                if await self.webViewEngine.load(track: track, config: config) {
                    self.activeEngine = self.webViewEngine
                    logger.info("Loaded '\(track.title)' via WebViewPlaybackEngine")
                    return true
                }
                self.webViewEngine.stop()
            }
        }
        return false
    }

    private func getTrack(track: Track, mediaSource: MediaSource) async -> GetTrackResponse? {
        let config = mediaSource.config
        guard let getTrackScript = config.data?.getTrack else {
            logger.error("No getTrack script in data config")
            return nil
        }

        guard let trackURL = track.url else {
            logger.error("Track has no URL")
            return nil
        }

        logger.info("Getting track via JS for track: \(track.title)")

        let encodedTrackURL = trackURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trackURL

        var context: [String: Any] = [:]
        context["trackUrl"] = encodedTrackURL
        context["trackTitle"] = track.title
        context["trackSubtitle"] = track.subtitle ?? ""
        context["metadata"] = track.metadata

        do {
            let result = try await JSExecutionEngine.shared.execute(
                script: getTrackScript.script,
                context: context,
                customUserAgent: config.customUserAgent,
                domain: config.url,
                mediaSourceContext: mediaSource.contextValues
            )

            return GetTrackResponse(
                streamUrl: result["streamUrl"] as? String,
                artworkUrlHD: result["artworkUrlHD"] as? String
            )
        } catch {
            logger.error("Stream URL JS execution failed: \(error.localizedDescription)")
            return nil
        }
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
