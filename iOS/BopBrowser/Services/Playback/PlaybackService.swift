import AVFoundation
import Foundation
import os
import UIKit

@Observable
@MainActor
final class PlaybackService: PlaybackEngineDelegate {
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

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "BopBrowser",
        category: "PlaybackService"
    )

    private let queueManager = SongQueueManager.shared
    private var activeEngine: PlaybackEngine?
    private var artworkCache: [String: UIImage] = [:]

    private init() {
        self.setupAudioSession()
        self.logger.info("PlaybackService initialized")
    }

    func playTrack(_ track: Song, queue: [Song] = [], mediaSource: MediaSource) {
        guard let config = mediaSource.config,
              let playbackConfig = config.playback
        else {
            self.logger.error("No playback config for source: \(mediaSource.name)")
            return
        }

        self.activeEngine?.teardown()
        self.activeEngine = nil

        self.currentTrack = track
        self.mediaSource = mediaSource
        self.isPlaying = false
        self.isLoading = true
        self.currentTime = 0
        self.duration = Double(track.duration ?? 0) / 1000.0

        if !queue.isEmpty {
            self.queueManager.setQueue(queue, startingAt: track)
        }

        let engine: PlaybackEngine

        switch playbackConfig.type {
        case .widget:
            guard let widgetConfig = playbackConfig.widget else {
                self.logger.error("Widget playback config missing for source: \(mediaSource.name)")
                return
            }
            let widgetEngine = WidgetPlaybackEngine(config: widgetConfig)
            engine = widgetEngine

        case .directStream:
            self.logger.warning("Direct stream playback not yet implemented")
            self.isLoading = false
            return
        }

        engine.delegate = self
        self.activeEngine = engine

        Task {
            await engine.load(track: track)
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
        self.activeEngine?.seek(to: time)
    }

    func engine(_ engine: PlaybackEngine, didReceiveEvent event: PlayerEvent) {
        switch event {
        case .playing:
            self.isPlaying = true
            self.isLoading = false
            self.logger.debug("Engine: playing")

        case .paused:
            self.isPlaying = false
            self.logger.debug("Engine: paused")

        case let .progress(currentTime, duration):
            self.currentTime = currentTime
            if duration > 0 {
                self.duration = duration
            }

        case let .durationResolved(duration):
            self.duration = duration
            self.logger.debug("Engine: duration resolved = \(duration)s")

        case .finished:
            self.logger.info("Engine: track finished")
            self.next()

        case let .error(message):
            self.isLoading = false
            self.logger.error("Engine error: \(message)")

        case .loading:
            self.isLoading = true

        case .ready:
            self.logger.debug("Engine: ready")
        }
    }

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            self.logger.info("Audio session configured for playback")
        } catch {
            self.logger.error("Audio session error: \(error.localizedDescription)")
        }
    }
}
