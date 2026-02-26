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
            self.state.originalQueue = queue
            if self.state.isShuffled {
                var shuffled = queue
                shuffled.shuffle()
                if let idx = shuffled.firstIndex(of: track) {
                    shuffled.remove(at: idx)
                    shuffled.insert(track, at: 0)
                }
                self.state.queue = shuffled
                self.state.currentIndex = 0
            } else {
                self.state.queue = queue
                self.state.currentIndex = queue.firstIndex(of: track) ?? 0
            }
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

        if self.state.repeatMode == .one {
            if let track = self.state.currentTrack, let source = self.state.mediaSource {
                self.playTrack(track, queue: self.state.queue, mediaSource: source)
            }
            return
        }

        if self.state.isShuffled {
            var randomIndex = Int.random(in: 0 ..< self.state.queue.count)
            if self.state.queue.count > 1 {
                while randomIndex == self.state.currentIndex {
                    randomIndex = Int.random(in: 0 ..< self.state.queue.count)
                }
            }
            self.state.currentIndex = randomIndex
        } else {
            let nextIndex = self.state.currentIndex + 1
            if nextIndex >= self.state.queue.count {
                if self.state.repeatMode == .all {
                    self.state.currentIndex = 0
                } else {
                    return
                }
            } else {
                self.state.currentIndex = nextIndex
            }
        }

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
            if self.state.isShuffled {
                var randomIndex = Int.random(in: 0 ..< self.state.queue.count)
                if self.state.queue.count > 1 {
                    while randomIndex == self.state.currentIndex {
                        randomIndex = Int.random(in: 0 ..< self.state.queue.count)
                    }
                }
                self.state.currentIndex = randomIndex
            } else {
                self.state.currentIndex = self.state.currentIndex > 0
                    ? self.state.currentIndex - 1
                    : self.state.queue.count - 1
            }
            let prevTrack = self.state.queue[self.state.currentIndex]
            if let source = self.state.mediaSource {
                self.playTrack(prevTrack, queue: self.state.queue, mediaSource: source)
            }
        }
    }

    func toggleShuffle() {
        self.state.isShuffled.toggle()

        if self.state.isShuffled {
            var shuffled = self.state.queue
            let currentTrack = self.state.currentTrack
            shuffled.shuffle()
            if let track = currentTrack, let idx = shuffled.firstIndex(of: track) {
                shuffled.remove(at: idx)
                shuffled.insert(track, at: 0)
            }
            self.state.queue = shuffled
            self.state.currentIndex = 0
        } else {
            self.state.queue = self.state.originalQueue
            if let track = self.state.currentTrack,
               let idx = self.state.queue.firstIndex(of: track)
            {
                self.state.currentIndex = idx
            }
        }
    }

    func cycleRepeatMode() {
        switch self.state.repeatMode {
        case .off:
            self.state.repeatMode = .all
        case .all:
            self.state.repeatMode = .one
        case .one:
            self.state.repeatMode = .off
        }
    }

    func seek(to time: Double) {
        self.state.currentTime = time
        self.activeEngine?.seek(to: time)
    }

    func moveQueueItem(fromOffsets source: IndexSet, toOffset destination: Int) {
        var queue = self.state.queue
        let items = source.map { queue[$0] }
        for index in source.sorted().reversed() {
            queue.remove(at: index)
        }
        let insertionIndex = min(destination, queue.count)
        queue.insert(contentsOf: items, at: insertionIndex)
        self.state.queue = queue
        if let currentTrack = self.state.currentTrack,
           let newIndex = self.state.queue.firstIndex(of: currentTrack)
        {
            self.state.currentIndex = newIndex
        }
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
