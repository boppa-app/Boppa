import AVFoundation
import Foundation
import MediaPlayer
import os
import UIKit

@Observable
@MainActor
final class PlaybackService: PlaybackEngineDelegate {
    static let shared = PlaybackService()

    private(set) var state = PlayerState()

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "BopBrowser",
        category: "PlaybackService"
    )

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

        self.state.currentTrack = track
        self.state.mediaSource = mediaSource
        self.state.isPlaying = false
        self.state.isLoading = true
        self.state.currentTime = 0
        self.state.duration = Double(track.duration ?? 0) / 1000.0

        if !queue.isEmpty {
            self.state.queue = queue
            self.state.currentIndex = queue.firstIndex(of: track) ?? 0
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
            self.state.isLoading = false
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
        self.state.isPlaying = true
    }

    func pause() {
        self.activeEngine?.pause()
        self.state.isPlaying = false
    }

    func togglePlayPause() {
        if self.state.isPlaying {
            self.pause()
        } else {
            self.play()
        }
    }

    func next() {
        guard !self.state.queue.isEmpty else { return }
        self.state.currentIndex = (self.state.currentIndex + 1) % self.state.queue.count
        let nextTrack = self.state.queue[self.state.currentIndex]
        if let source = self.state.mediaSource {
            self.playTrack(nextTrack, queue: self.state.queue, mediaSource: source)
        }
    }

    func previous() {
        guard !self.state.queue.isEmpty else { return }
        if self.state.currentTime > 3 {
            self.seek(to: 0)
        } else {
            self.state.currentIndex = self.state.currentIndex > 0
                ? self.state.currentIndex - 1
                : self.state.queue.count - 1
            let prevTrack = self.state.queue[self.state.currentIndex]
            if let source = self.state.mediaSource {
                self.playTrack(prevTrack, queue: self.state.queue, mediaSource: source)
            }
        }
    }

    func seek(to time: Double) {
        self.state.currentTime = time
        self.activeEngine?.seek(to: time)
    }

    func engine(_ engine: PlaybackEngine, didReceiveEvent event: PlayerEvent) {
        switch event {
        case .playing:
            self.state.isPlaying = true
            self.state.isLoading = false
            self.logger.debug("Engine: playing")

        case .paused:
            self.state.isPlaying = false
            self.logger.debug("Engine: paused")

        case let .progress(currentTime, duration):
            self.state.currentTime = currentTime
            if duration > 0 {
                self.state.duration = duration
            }

        case let .durationResolved(duration):
            self.state.duration = duration
            self.logger.debug("Engine: duration resolved = \(duration)s")

        case .finished:
            self.logger.info("Engine: track finished")
            self.next()

        case let .error(message):
            self.state.isLoading = false
            self.logger.error("Engine error: \(message)")

        case .loading:
            self.state.isLoading = true

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
