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

    private static let artworkPreloadWindow = 50

    private(set) var currentTrack: Track?
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
    private var preloadedArtworkUrls: Set<String> = []
    private var userPaused: Bool = false

    private init() {
        self.observeMediaSourceRemoved()
        logger.info("PlaybackService initialized")
    }

    func playTrack(_ track: Track, queue: [Track] = []) {
        let mediaSourceId = track.mediaSourceId
        logger.info("playTrack: using mediaSource '\(mediaSourceId)'")

        self.currentTrack = track
        self.isPlaying = false
        self.isLoading = true
        self.currentTime = 0
        self.duration = Double(track.duration ?? 0) / 1000.0

        if !queue.isEmpty {
            self.queueManager.setQueue(queue, startingAt: track)
        }

        Task {
            guard let engine = self.registry.engine(for: mediaSourceId) else {
                logger.error("No playback engine for media source '\(mediaSourceId)'")
                self.isLoading = false
                return
            }

            if let currentEngine = self.activeEngine, currentEngine !== engine {
                logger.info("Engine switch detected — pausing previous engine")
                currentEngine.pause()
            }

            engine.onEvent = { [weak self] event in
                self?.handleEngineEvent(event)
            }

            self.activeEngine = engine

            let shouldRestartKeepalive = self.userPaused
            if shouldRestartKeepalive {
                self.userPaused = false
            }

            if await engine.load(track: track, shouldRestartKeepalive: shouldRestartKeepalive) {
                logger.info("Loaded '\(track.title)' via WebViewPlaybackEngine")
            } else {
                logger.error("Failed to load '\(track.title)'")
                self.isLoading = false
            }

            self.updateArtworkPreloads()
        }
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

    func next() {
        guard let nextTrack = self.queueManager.advanceToNext() else { return }
        self.playTrack(nextTrack)
    }

    func previous() {
        guard !self.queueManager.queue.isEmpty else { return }
        if self.currentTime > 3 {
            self.seek(to: 0)
        } else {
            guard let prevTrack = self.queueManager.rewindToPrevious() else { return }
            self.playTrack(prevTrack)
        }
    }

    // MARK: - Artwork Preloading

    private func updateArtworkPreloads() {
        guard let engine = self.activeEngine else { return }

        let queue = self.queueManager.queue
        let currentIndex = self.queueManager.currentIndex
        guard !queue.isEmpty else { return }

        let window = Self.artworkPreloadWindow
        let startIndex = max(0, currentIndex - window)
        let endIndex = min(queue.count - 1, currentIndex + window)

        var desiredUrls: Set<String> = []
        for i in startIndex ... endIndex {
            if let remoteUrl = queue[i].artworkUrl,
               let localUrl = ArtworkServer.localURL(for: remoteUrl)
            {
                desiredUrls.insert(localUrl)
            }
        }

        let toAdd = desiredUrls.subtracting(self.preloadedArtworkUrls)
        let toRemove = self.preloadedArtworkUrls.subtracting(desiredUrls)

        if !toAdd.isEmpty {
            engine.preloadArtwork(urls: Array(toAdd))
        }
        if !toRemove.isEmpty {
            engine.removeArtwork(urls: Array(toRemove))
        }

        self.preloadedArtworkUrls = desiredUrls
    }

    func seek(to time: Double) {
        self.currentTime = time
        self.activeEngine?.seek(to: time)
    }

    func stop() {
        self.activeEngine?.stop()
        self.activeEngine = nil
        self.currentTrack = nil
        self.isPlaying = false
        self.isLoading = false
        self.currentTime = 0
        self.duration = 0
        self.preloadedArtworkUrls = []
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
