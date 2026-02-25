import Foundation

enum PlayerEvent {
    case playing
    case paused
    case progress(currentTime: Double, duration: Double)
    case durationResolved(Double)
    case finished
    case error(String)
    case loading
    case ready
}

struct PlayerState {
    var currentTrack: Song?
    var mediaSource: MediaSource?
    var isPlaying: Bool = false
    var isLoading: Bool = false
    var currentTime: Double = 0
    var duration: Double = 0
    var queue: [Song] = []
    var currentIndex: Int = 0

    var hasTrack: Bool {
        self.currentTrack != nil
    }
}
