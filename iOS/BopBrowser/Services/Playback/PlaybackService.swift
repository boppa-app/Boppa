import AVFoundation
import Foundation
import os

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "BopBrowser",
    category: "PlaybackService"
)

@Observable
@MainActor
final class PlaybackService {
    static let shared = PlaybackService()

    private(set) var currentTrack: Song?
    private(set) var mediaSource: MediaSource?
    private(set) var isPlaying: Bool = false
    private(set) var isLoading: Bool = false
    private(set) var currentTime: Double = 0
    private(set) var duration: Double = 0

    var hasTrack: Bool {
        self.currentTrack != nil
    }

    private let queueManager = SongQueueManager.shared
    private let engine = PlaybackEngine.shared

    private init() {
        self.setupAudioSession()
        self.engine.onEvent = { [weak self] event in
            self?.handleEngineEvent(event)
        }
        logger.info("PlaybackService initialized")
    }

    func playTrack(_ track: Song, queue: [Song] = [], mediaSource: MediaSource) {
        guard let config = mediaSource.config,
              let playbackConfig = config.playback
        else {
            logger.error("No playback config for source: \(mediaSource.name)")
            return
        }

        self.engine.teardown()

        self.currentTrack = track
        self.mediaSource = mediaSource
        self.isPlaying = false
        self.isLoading = true
        self.currentTime = 0
        self.duration = Double(track.duration ?? 0) / 1000.0

        if !queue.isEmpty {
            self.queueManager.setQueue(queue, startingAt: track)
        }

        Task {
            await self.engine.load(track: track, config: playbackConfig, mediaSource: mediaSource)
        }
    }

    func play() {
        self.engine.play()
        self.isPlaying = true
    }

    func pause() {
        self.engine.pause()
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
        if let source = self.mediaSource {
            self.playTrack(nextTrack, mediaSource: source)
        }
    }

    func previous() {
        guard !self.queueManager.queue.isEmpty else { return }
        if self.currentTime > 3 {
            self.seek(to: 0)
        } else {
            guard let prevTrack = self.queueManager.rewindToPrevious() else { return }
            if let source = self.mediaSource {
                self.playTrack(prevTrack, mediaSource: source)
            }
        }
    }

    func seek(to time: Double) {
        self.currentTime = time
        self.engine.seek(to: time)
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
