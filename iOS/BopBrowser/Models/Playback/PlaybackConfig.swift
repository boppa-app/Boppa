import Foundation

struct PlaybackConfig: Codable, Sendable {
    let mode: PlaybackMode
    let url: String?
    let html: ScriptContent?
    let streamUrl: ScriptContent?
    let userScripts: [Script]?
}

enum PlaybackMode: String, Codable, Sendable {
    case streamOnly
    case webOnly
    case webFallback
    case streamFallback
}
