import Foundation
import os

// TODO: If switching media source configs dont execute search unless user clicks, instead clear search results
// TODO: Save search source preference

@MainActor
class SearchService {
    static let shared = SearchService()

    private init() {}

    @MainActor
    func search(
        query: String,
        mediaSource: StoredMediaSource,
        category: SearchCategory
    ) async throws -> SearchResponse {
        let config = mediaSource.config
        guard let search = config.data.search else {
            throw SearchError.noSearchConfig
        }
        guard let script = category.script(from: search) else {
            throw SearchError.noSearchConfig
        }
        let jsResult = try await JSExecutionEngine.shared.execute(
            script: script,
            params: ["query": query],
            domain: config.url,
            context: mediaSource.contextValues,
            allowedUrls: config.effectiveAllowedUrls
        )
        return self.buildResponse(jsResult: jsResult, category: category, mediaSourceId: config.id)
    }

    @MainActor
    func searchNextPage(
        continuation: [String: Any],
        mediaSource: StoredMediaSource,
        category: SearchCategory,
        query: String
    ) async throws -> SearchResponse {
        let config = mediaSource.config
        guard let search = config.data.search else {
            throw SearchError.noSearchConfig
        }
        guard let script = category.script(from: search) else {
            throw SearchError.noSearchConfig
        }
        let jsResult = try await JSExecutionEngine.shared.execute(
            script: script,
            params: scriptParams(["query": query], previousResult: continuation),
            domain: config.url,
            context: mediaSource.contextValues,
            allowedUrls: config.effectiveAllowedUrls
        )
        return self.buildResponse(jsResult: jsResult, category: category, mediaSourceId: config.id)
    }

    private func buildResponse(jsResult: [String: Any], category: SearchCategory, mediaSourceId: String) -> SearchResponse {
        switch category {
        case .songs:
            let response = SearchSongsResponse(jsResult)
            return SearchResponse(
                result: .songs(response.items.map { $0.toTrack(mediaSourceId: mediaSourceId) }),
                continuation: response.continuation
            )
        case .videos:
            let response = SearchVideosResponse(jsResult)
            return SearchResponse(
                result: .videos(response.items.map { $0.toTrack(mediaSourceId: mediaSourceId, type: .video) }),
                continuation: response.continuation
            )
        case .albums:
            let response = SearchAlbumsResponse(jsResult)
            return SearchResponse(
                result: .albums(response.items.map { $0.toTracklist(mediaSourceId: mediaSourceId, tracklistType: .album) }),
                continuation: response.continuation
            )
        case .artists:
            let response = SearchArtistsResponse(jsResult)
            return SearchResponse(
                result: .artists(response.items.map { $0.toArtist(mediaSourceId: mediaSourceId) }),
                continuation: response.continuation
            )
        case .playlists:
            let response = SearchPlaylistsResponse(jsResult)
            return SearchResponse(
                result: .playlists(response.items.map { $0.toTracklist(mediaSourceId: mediaSourceId, tracklistType: .playlist) }),
                continuation: response.continuation
            )
        }
    }
}
