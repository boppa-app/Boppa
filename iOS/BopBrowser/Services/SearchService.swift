import Foundation
import os

// TODO: If switching media source configs dont execute search unless user clicks, instead clear search results

class SearchService {
    static let shared = SearchService()

    private init() {}

    @MainActor
    func search(
        query: String,
        config: MediaSourceConfig,
        category: SearchCategory,
        contextService: MediaSourceContextService
    ) async throws -> SearchResponse {
        guard let data = config.data else {
            throw SearchError.noSearchConfig
        }

        guard let script = category.script(from: data) else {
            throw SearchError.noSearchConfig
        }

        let context = self.buildJSContext(query: query, previousResult: nil, contextService: contextService)
        let jsResult = try await JSExecutionEngine.shared.execute(script: script, context: context)
        return self.parseJSResult(jsResult, category: category, mediaSourceName: config.name)
    }

    @MainActor
    func searchNextPage(
        paginationContext: [String: Any],
        config: MediaSourceConfig,
        category: SearchCategory,
        query: String,
        contextService: MediaSourceContextService
    ) async throws -> SearchResponse {
        guard let data = config.data else {
            throw SearchError.noSearchConfig
        }

        guard let script = category.script(from: data) else {
            throw SearchError.noSearchConfig
        }

        let context = self.buildJSContext(query: query, previousResult: paginationContext, contextService: contextService)
        let jsResult = try await JSExecutionEngine.shared.execute(script: script, context: context)
        return self.parseJSResult(jsResult, category: category, mediaSourceName: config.name)
    }

    private func buildJSContext(query: String, previousResult: [String: Any]?, contextService: MediaSourceContextService) -> [String: Any] {
        var context: [String: Any] = [:]
        context["query"] = query
        context["capturedValues"] = contextService.allContextData()

        if let previousResult {
            context["previousResult"] = previousResult
        }

        return context
    }

    private func parseJSResult(_ jsResult: [String: Any], category: SearchCategory, mediaSourceName: String) -> SearchResponse {
        let items: [[String: Any]]
        if let itemsArray = jsResult["items"] as? [[String: Any]] {
            items = itemsArray
        } else {
            items = []
        }

        let result: SearchResult
        switch category {
        case .songs:
            result = .songs(items.compactMap { self.mapToSong($0, mediaSourceName: mediaSourceName) })
        case .albums:
            result = .albums(items.compactMap(self.mapToAlbum))
        case .artists:
            result = .artists(items.compactMap(self.mapToArtist))
        case .playlists:
            result = .playlists(items.compactMap(self.mapToPlaylist))
        }

        var paginationData = jsResult
        paginationData.removeValue(forKey: "items")
        let hasPaginationContext = paginationData.values.contains { !($0 is NSNull) }
        let paginationContext: [String: Any]? = hasPaginationContext ? jsResult : nil
        return SearchResponse(result: result, paginationContext: paginationContext)
    }

    private func mapToSong(_ item: [String: Any], mediaSourceName: String) -> Song? {
        guard let title = item["title"] as? String else { return nil }
        return Song(
            title: title,
            artist: item["artist"] as? String,
            duration: self.resolveInt(item["duration"]),
            artworkUrl: item["artworkUrl"] as? String,
            url: item["url"] as? String,
            mediaSourceName: mediaSourceName
        )
    }

    private func mapToAlbum(_ item: [String: Any]) -> Album? {
        guard let title = item["title"] as? String else { return nil }
        return Album(
            title: title,
            artist: item["artist"] as? String,
            trackCount: self.resolveInt(item["trackCount"]),
            artworkUrl: item["artworkUrl"] as? String,
            url: item["url"] as? String
        )
    }

    private func mapToArtist(_ item: [String: Any]) -> Artist? {
        guard let name = (item["name"] as? String) ?? (item["artist"] as? String) else { return nil }
        return Artist(
            name: name,
            artworkUrl: item["artworkUrl"] as? String,
            url: item["url"] as? String
        )
    }

    private func mapToPlaylist(_ item: [String: Any]) -> Playlist? {
        guard let title = item["title"] as? String else { return nil }
        return Playlist(
            title: title,
            user: item["user"] as? String,
            trackCount: self.resolveInt(item["trackCount"]),
            artworkUrl: item["artworkUrl"] as? String,
            url: item["url"] as? String
        )
    }

    private func resolveInt(_ value: Any?) -> Int? {
        if let intValue = value as? Int { return intValue }
        if let doubleValue = value as? Double { return Int(doubleValue) }
        if let stringValue = value as? String { return Int(stringValue) }
        return nil
    }
}
