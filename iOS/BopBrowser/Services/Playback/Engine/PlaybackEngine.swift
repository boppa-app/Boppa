import Foundation

enum PlaybackSource {
    case track(track: Track, config: MediaSourceConfig)
    case getTrackResponse(getTrackResponse: GetTrackResponse)
}

@MainActor
protocol PlaybackEngine: AnyObject {
    var onEvent: ((PlayerEvent) -> Void)? { get set }

    func load(source: PlaybackSource) async -> Bool
    func play()
    func pause()
    func seek(to timeSeconds: Double)
    func stop()
}

extension PlaybackEngine {
    func load(track: Track, config: MediaSourceConfig) async -> Bool {
        await self.load(source: .track(track: track, config: config))
    }

    func load(getTrackResponse: GetTrackResponse) async -> Bool {
        await self.load(source: .getTrackResponse(getTrackResponse: getTrackResponse))
    }
}
