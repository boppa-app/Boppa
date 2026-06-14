import Foundation

struct SearchResponse {
    let result: SearchResult
    let continuation: [String: Any]?
}
