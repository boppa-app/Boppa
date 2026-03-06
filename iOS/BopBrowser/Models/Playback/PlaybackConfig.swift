import Foundation

struct PlaybackConfig: Codable {
    let url: String?
    let html: ScriptContent?
    let scripts: [ScrapeScript]
    let customUserAgent: String?
}
