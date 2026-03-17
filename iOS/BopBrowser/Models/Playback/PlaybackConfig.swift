import Foundation

struct PlaybackConfig: Codable, Sendable {
    let url: String?
    let html: ScriptContent?
    let streamUrl: ScriptContent?
    let userScripts: [Script]
}
