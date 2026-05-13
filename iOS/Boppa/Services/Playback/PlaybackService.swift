import AVFoundation
import Foundation
import os

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "Boppa",
    category: "PlaybackService"
)

@Observable
@MainActor
final class PlaybackService {
    static let shared = PlaybackService()

    private(set) var currentTrack: Track?
    private(set) var mediaSource: MediaSource?
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

    private init() {
        self.setupAudioSession()
        self.observeMediaSourceRemoved()
        logger.info("PlaybackService initialized")
    }

    func playTrack(_ track: Track, queue: [Track] = [], mediaSource: MediaSource) {
        self.activeEngine?.stop()

        self.currentTrack = track
        self.mediaSource = mediaSource
        self.isPlaying = false
        self.isLoading = true
        self.currentTime = 0
        self.duration = Double(track.duration ?? 0) / 1000.0

        if !queue.isEmpty {
            self.queueManager.setQueue(queue, startingAt: track)
        }

        // TODO: Stop the current engine (set page to blanks) if engine swaps to a different one after different one loads
        Task {
            guard let engine = self.registry.engine(for: mediaSource.id) else {
                logger.error("No playback engine for media source '\(mediaSource.id)'")
                self.isLoading = false
                return
            }

            engine.onEvent = { [weak self] event in
                self?.handleEngineEvent(event)
            }

            self.activeEngine = engine

            if await engine.load(track: track) {
                logger.info("Loaded '\(track.title)' via WebViewPlaybackEngine")
            } else {
                logger.error("Failed to load '\(track.title)'")
                self.isLoading = false
            }
        }
    }

    func play() {
        self.activeEngine?.play()
        self.isPlaying = true
    }

    func pause() {
        self.activeEngine?.pause()
        self.isPlaying = false
    }

    func togglePlayPause() {
        if self.isPlaying {
            self.pause()
        } else {
            self.play()
        }
    }

    func next() {
        guard let nextTrack = self.queueManager.advanceToNext() else { return }
        if let mediaSource = self.mediaSource {
            self.playTrack(nextTrack, mediaSource: mediaSource)
        }
    }

    func previous() {
        guard !self.queueManager.queue.isEmpty else { return }
        if self.currentTime > 3 {
            self.seek(to: 0)
        } else {
            guard let prevTrack = self.queueManager.rewindToPrevious() else { return }
            if let mediaSource = self.mediaSource {
                self.playTrack(prevTrack, mediaSource: mediaSource)
            }
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
        self.mediaSource = nil
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
            logger.debug("Engine: playing")

        case .paused:
            self.isPlaying = false
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

    private func handleMediaSourceRemoved(ids: [String]) {
        if let currentMediaSource = self.mediaSource, ids.contains(currentMediaSource.id) {
            self.stop()
            logger.info("Stopped playback: media source '\(currentMediaSource.id)' was removed")
            return
        }

        for id in ids {
            self.queueManager.removeTracks(forMediaSource: id)
            logger.info("Removed queued tracks for deleted media source: \(id)")
        }
    }

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            logger.info("Audio session configured for playback")
        } catch {
            logger.error("Audio session error: \(error.localizedDescription)")
        }
    }
}
