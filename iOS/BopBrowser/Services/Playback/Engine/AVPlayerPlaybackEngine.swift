import AVFoundation
import Foundation
import os

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "BopBrowser",
    category: "AVPlayerPlaybackEngine"
)

@MainActor
final class AVPlayerPlaybackEngine: PlaybackEngine {
    static let shared = AVPlayerPlaybackEngine()

    var onEvent: ((PlayerEvent) -> Void)?

    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    private var statusObservation: NSKeyValueObservation?
    private var rateObservation: NSKeyValueObservation?
    private var didFinishObserver: NSObjectProtocol?

    private init() {}

    func load(playbackSource: PlaybackSource) async -> Bool {
        switch playbackSource {
        case let .track(track, config):
            logger.error("No streamUrl provided to AVPlayerPlaybackEngine")
            return false

        case let .getTrackResponse(getTrackResponse):
            guard let streamUrlString = getTrackResponse.streamUrl,
                  let streamUrl = URL(string: streamUrlString)
            else {
                logger.error("No streamUrl provided to AVPlayerPlaybackEngine")
                return false
            }
            self.stop()
            self.startPlayback(url: streamUrl)
            return true
        }
    }

    func play() {
        self.player?.play()
    }

    func pause() {
        self.player?.pause()
    }

    func seek(to timeSeconds: Double) {
        let cmTime = CMTime(seconds: timeSeconds, preferredTimescale: 1000)
        self.player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func stop() {
        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
        }
        self.timeObserver = nil

        self.statusObservation?.invalidate()
        self.statusObservation = nil

        self.rateObservation?.invalidate()
        self.rateObservation = nil

        if let didFinishObserver {
            NotificationCenter.default.removeObserver(didFinishObserver)
        }
        self.didFinishObserver = nil

        self.player?.pause()
        self.player?.replaceCurrentItem(with: nil)
        self.player = nil
        self.playerItem = nil

        logger.info("AVPlayerPlaybackEngine stopped")
    }

    private func startPlayback(url: URL) {
        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        self.playerItem = item

        let player = AVPlayer(playerItem: item)
        player.automaticallyWaitsToMinimizeStalling = true
        self.player = player

        self.observeStatus(item: item)
        self.observeRate(player: player)
        self.observeFinish(item: item)
        self.addPeriodicTimeObserver(player: player)
    }

    private func observeStatus(item: AVPlayerItem) {
        self.statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch item.status {
                case .readyToPlay:
                    let duration = item.duration.seconds
                    if duration.isFinite, duration > 0 {
                        logger.info("Stream ready. Duration: \(duration)s")
                        self.onEvent?(.durationResolved(duration))
                    } else {
                        logger.info("Stream ready (live or unknown duration)")
                    }
                    self.onEvent?(.ready)
                    self.player?.play()

                case .failed:
                    let message = item.error?.localizedDescription ?? "Unknown AVPlayer error"
                    logger.error("AVPlayerItem failed: \(message)")
                    self.onEvent?(.error(message))

                case .unknown:
                    break

                @unknown default:
                    break
                }
            }
        }
    }

    private func observeRate(player: AVPlayer) {
        self.rateObservation = player.observe(\.rate, options: [.new]) { [weak self] player, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if player.rate > 0 {
                    self.onEvent?(.playing)
                } else if player.currentItem?.status == .readyToPlay {
                    self.onEvent?(.paused)
                }
            }
        }
    }

    private func observeFinish(item: AVPlayerItem) {
        self.didFinishObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                logger.info("Stream playback finished")
                self.onEvent?(.finished)
            }
        }
    }

    private func addPeriodicTimeObserver(player: AVPlayer) {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 1000)
        self.timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let currentTime = time.seconds
                let duration = self.playerItem?.duration.seconds ?? 0
                let safeDuration = (duration.isFinite && duration > 0) ? duration : 0
                self.onEvent?(.progress(currentTime: currentTime, duration: safeDuration))
            }
        }
    }
}
