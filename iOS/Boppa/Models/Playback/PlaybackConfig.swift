import Foundation

struct PlaybackConfig: Codable, Sendable {
    let url: String?
    let html: ScriptContent?
    let userScripts: [Script]?
}
