import Foundation

struct PlaybackConfig: Codable, Sendable {
    let bodyHtml: ScriptContent
    let userScripts: [Script]?
}
