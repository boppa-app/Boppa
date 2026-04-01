import Foundation

@MainActor
protocol PlaybackEngine: AnyObject {
    var onEvent: ((PlayerEvent) -> Void)? { get set }

    func load(track: Track, config: MediaSourceConfig) async -> Bool
    func play()
    func pause()
    func seek(to timeSeconds: Double)
    func stop()
}
