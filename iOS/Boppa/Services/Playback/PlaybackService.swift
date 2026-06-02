import AVFoundation
import Foundation
import os

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "Boppa",
    category: "PlaybackService"
)

// TODO: Set seek to 0 when loading next track

@Observable
@MainActor
final class PlaybackService {
    static let shared = PlaybackService()

    private(set) var currentTrack: Track?
    private(set) var currentContextId: String?
    private(set) var isPlaying: Bool = false
    private(set) var isLoading: Bool = false
    private(set) var currentTime: Double = 0
    private(set) var duration: Double = 0

    var hasTrack: Bool {
        self.currentTrack != nil
    }

    private let queueManager = TrackQueueManager.shared
    private let registry = WebViewPlaybackEngineRegistry.shared
    private var activeEngine: WebViewPlaybackEngine?

    private var mediaSourceRemovedObserver: NSObjectProtocol?
    private var mediaSourceDisabledObserver: NSObjectProtocol?
    private var userPaused: Bool = false

    private static let previousTrackSeekThreshold: Double = 3

    private init() {
        self.observeMediaSourceRemoved()
        self.observeMediaSourceDisabled()
        logger.info("PlaybackService initialized")
    }

    func playTrack(_ track: Track, queue: [Track] = [], startingAt index: Int? = nil, contextId: String? = nil) {
        if let contextId {
            self.currentContextId = contextId
        }

        let mediaSourceId = track.mediaSourceId
        logger.info("playTrack: using mediaSource '\(mediaSourceId)'")

        self.currentTrack = track
        self.isPlaying = false
        self.isLoading = true
        self.currentTime = 0
        self.duration = Double(track.duration ?? 0) / 1000.0

        if !queue.isEmpty {
            if let index {
                self.queueManager.setQueue(queue, startingAt: index)
            } else {
                self.queueManager.setQueue(queue, startingAt: track)
            }
        }

        guard let engine = self.registry.engine(for: mediaSourceId) else {
            logger.error("No playback engine for media source '\(mediaSourceId)'")
            self.isLoading = false
            return
        }

        // Silence old engine's event handler immediately, before any await, so
        // interruption-induced pause/play events from it doesn't pollute our state.
        let previousEngine = self.activeEngine !== engine ? self.activeEngine : nil
        previousEngine?.onEvent = nil

        engine.onEvent = { [weak self] event in
            self?.handleEngineEvent(event)
        }

        let isSwitchingEngines = previousEngine != nil

        engine.setNowPlayingInfo(track: track)
        // Modify the previous engine's MediaSession metadata so that subsequent loads on it
        // trigger MediaSession metadata mutation and avoid blank artwork in NowPlayingInfo
        if isSwitchingEngines { previousEngine?.setNowPlayingInfo(track: track) }
        engine.activateNowPlayingInfo()

        if let previousEngine {
            previousEngine.pause(shouldPauseKeepAlive: false)
        }
        engine.pause(shouldPauseKeepAlive: false)
        engine.load(track: track)

        if let previousEngine {
            logger.info("Engine switch detected — deactivating previous engine")
            previousEngine.deactivateNowPlayingInfo()
            previousEngine.pause(shouldPauseKeepAlive: !isSwitchingEngines)
        }
        self.activeEngine = engine
    }

    func play() {
        self.activeEngine?.play()
    }

    func pause() {
        self.activeEngine?.pause()
    }

    func togglePlayPause() {
        if self.isPlaying {
            self.pause()
        } else {
            self.play()
        }
    }

    func next(userInitiated: Bool = false) {
        if userInitiated { self.queueManager.clearRepeatOne() }
        guard let nextTrack = self.queueManager.advanceToNext() else { return }
        self.playTrack(nextTrack)
    }

    func previous(userInitiated: Bool = false) {
        guard !self.queueManager.queue.isEmpty else { return }
        if self.currentTime > Self.previousTrackSeekThreshold {
            self.seek(to: 0)
        } else {
            if userInitiated { self.queueManager.clearRepeatOne() }
            guard let prevTrack = self.queueManager.rewindToPrevious() else { return }
            self.playTrack(prevTrack)
        }
    }

    func seek(to time: Double) {
        self.currentTime = time
        self.activeEngine?.seek(to: time)
    }

    func stop() {
        self.activeEngine?.stop()
        self.activeEngine = nil
        self.currentTrack = nil
        self.currentContextId = nil
        self.isPlaying = false
        self.isLoading = false
        self.currentTime = 0
        self.duration = 0
        self.queueManager.clearQueue()
        logger.info("Playback stopped and cleared")
    }

    private func handleEngineEvent(_ event: PlayerEvent) {
        switch event {
        case .playing:
            self.isPlaying = true
            self.isLoading = false
            self.userPaused = false
            logger.debug("Engine: playing")

        case .paused:
            self.isPlaying = false
            self.userPaused = true
            logger.debug("Engine: paused")

        case let .progress(currentTime, duration):
            self.currentTime = currentTime
            if duration > 0 {
                self.duration = duration
            }

        case let .durationResolved(duration):
            self.duration = duration
            logger.debug("Engine: duration resolved = \(duration)s")

        case .finished:
            logger.info("Engine: track finished")
            self.next()

        case let .error(message):
            self.isLoading = false
            logger.error("Engine error: \(message)")

        case .loading:
            self.isLoading = true

        case .ready:
            logger.debug("Engine: ready")
        }
    }

    private func observeMediaSourceRemoved() {
        self.mediaSourceRemovedObserver = NotificationCenter.default.addObserver(
            forName: .mediaSourceRemoved,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                guard let self,
                      let ids = notification.userInfo?["ids"] as? [String]
                else { return }
                self.handleMediaSourceRemoved(ids: ids)
            }
        }
    }

    private func observeMediaSourceDisabled() {
        self.mediaSourceDisabledObserver = NotificationCenter.default.addObserver(
            forName: .mediaSourceDisabled,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                guard let self,
                      let id = notification.userInfo?["id"] as? String
                else { return }
                self.handleMediaSourceRemoved(ids: [id])
            }
        }
    }

    private func handleMediaSourceRemoved(ids: [String]) {
        if let currentTrack = self.currentTrack, ids.contains(currentTrack.mediaSourceId) {
            self.stop()
            logger.info("Stopped playback: media source '\(currentTrack.mediaSourceId)' was removed")
            return
        }

        for id in ids {
            self.queueManager.removeTracks(forMediaSource: id)
            logger.info("Removed queued tracks for deleted media source: \(id)")
        }
    }
}
