import Foundation

struct PlaybackConfig: Codable {
    let url: String?
    let html: ScriptContent?
    let streamUrl: ScriptContent?
    let userScripts: [Script]
}
