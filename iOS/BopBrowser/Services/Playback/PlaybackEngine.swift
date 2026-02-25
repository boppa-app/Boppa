import Foundation

@MainActor
protocol PlaybackEngine: AnyObject {
    var delegate: PlaybackEngineDelegate? { get set }
    func load(track: Song) async
    func play()
    func pause()
    func seek(to timeSeconds: Double)
    func teardown()
}

@MainActor
protocol PlaybackEngineDelegate: AnyObject {
    func engine(_ engine: PlaybackEngine, didReceiveEvent event: PlayerEvent)
}
