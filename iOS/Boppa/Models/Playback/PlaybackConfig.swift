import Foundation

struct PlaybackConfig: Codable, Sendable {
    let html: ScriptContent
    let userScripts: [Script]?
}
