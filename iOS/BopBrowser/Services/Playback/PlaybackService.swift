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
    private let playbackManager = PlaybackManager.shared

    private var mediaSourceRemovedObserver: NSObjectProtocol?

    private init() {
        self.setupAudioSession()
        self.playbackManager.onEvent = { [weak self] event in
            self?.handleManagerEvent(event)
        }
        self.observeMediaSourceRemoved()
        logger.info("PlaybackService initialized")
    }

    func playTrack(_ track: Song, queue: [Song] = [], mediaSource: MediaSource) {
        self.playbackManager.stop()

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
            await self.playbackManager.load(track: track, mediaSource: mediaSource)
        }
    }

    func play() {
        self.playbackManager.play()
        self.isPlaying = true
    }

    func pause() {
        self.playbackManager.pause()
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
        self.playbackManager.seek(to: time)
    }

    private func handleManagerEvent(_ event: PlayerEvent) {
        switch event {
        case .playing:
            self.isPlaying = true
            self.isLoading = false
            logger.debug("Manager: playing")

        case .paused:
            self.isPlaying = false
            logger.debug("Manager: paused")

        case let .progress(currentTime, duration):
            self.currentTime = currentTime
            if duration > 0 {
                self.duration = duration
            }

        case let .durationResolved(duration):
            self.duration = duration
            logger.debug("Manager: duration resolved = \(duration)s")

        case .finished:
            logger.info("Manager: track finished")
            self.next()

        case let .error(message):
            self.isLoading = false
            logger.error("Manager error: \(message)")

        case .loading:
            self.isLoading = true

        case .ready:
            logger.debug("Manager: ready")
        }
    }

    func stop() {
        self.playbackManager.stop()
        self.currentTrack = nil
        self.mediaSource = nil
        self.isPlaying = false
        self.isLoading = false
        self.currentTime = 0
        self.duration = 0
        self.queueManager.clearQueue()
        logger.info("Playback stopped and cleared")
    }

    private func observeMediaSourceRemoved() {
        self.mediaSourceRemovedObserver = NotificationCenter.default.addObserver(
            forName: .mediaSourceRemoved,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                guard let self,
                      let names = notification.userInfo?["names"] as? [String]
                else { return }
                self.handleMediaSourceRemoved(names: names)
            }
        }
    }

    private func handleMediaSourceRemoved(names: [String]) {
        if let currentSource = self.mediaSource, names.contains(currentSource.name) {
            self.stop()
            logger.info("Stopped playback: media source '\(currentSource.name)' was removed")
            return
        }

        for name in names {
            self.queueManager.removeSongs(forMediaSource: name)
            logger.info("Removed queued songs for deleted media source: \(name)")
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
