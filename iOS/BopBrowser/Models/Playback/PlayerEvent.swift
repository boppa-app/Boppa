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
