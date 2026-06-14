import Foundation
import os

// TODO: If switching media source configs dont execute search unless user clicks, instead clear search results
// TODO: Save search source preference

@MainActor
class SearchService {
    static let shared = SearchService()

    private let paginated = PaginatedScriptExecutor.shared

    private init() {}

    @MainActor
    func search(
        query: String,
        mediaSource: MediaSource,
        category: SearchCategory
    ) async throws -> SearchResponse {
        let config = mediaSource.config
        guard let search = config.search else {
            throw SearchError.noSearchConfig
        }
        guard let script = category.script(from: search) else {
            throw SearchError.noSearchConfig
        }
        let jsResult = try await paginated.executeRaw(
            script: script,
            params: ["query": query],
            customUserAgent: config.customUserAgent,
            domain: config.url,
            context: mediaSource.contextValues
        )
        return self.buildResponse(jsResult: jsResult, category: category, mediaSourceId: config.id)
    }

    @MainActor
    func searchNextPage(
        paginationContext: [String: Any],
        mediaSource: MediaSource,
        category: SearchCategory,
        query: String
    ) async throws -> SearchResponse {
        let config = mediaSource.config
        guard let search = config.search else {
            throw SearchError.noSearchConfig
        }
        guard let script = category.script(from: search) else {
            throw SearchError.noSearchConfig
        }
        let jsResult = try await paginated.executeRaw(
            script: script,
            params: ["query": query],
            previousResult: paginationContext,
            customUserAgent: config.customUserAgent,
            domain: config.url,
            context: mediaSource.contextValues
        )
        return self.buildResponse(jsResult: jsResult, category: category, mediaSourceId: config.id)
    }

    private func buildResponse(jsResult: [String: Any], category: SearchCategory, mediaSourceId: String) -> SearchResponse {
        switch category {
        case .songs:
            let response = SearchSongsResponse(jsResult)
            return SearchResponse(
                result: .songs(response.items.map { self.paginated.mapToTrack($0, mediaSourceId: mediaSourceId) }),
                paginationContext: response.paginationContext
            )
        case .videos:
            let response = SearchVideosResponse(jsResult)
            return SearchResponse(
                result: .videos(response.items.map { self.paginated.mapToTrack($0, mediaSourceId: mediaSourceId) }),
                paginationContext: response.paginationContext
            )
        case .albums:
            let response = SearchAlbumsResponse(jsResult)
            return SearchResponse(
                result: .albums(response.items.map { self.paginated.mapToTracklist($0, mediaSourceId: mediaSourceId, tracklistType: .album) }),
                paginationContext: response.paginationContext
            )
        case .artists:
            let response = SearchArtistsResponse(jsResult)
            return SearchResponse(
                result: .artists(response.items.map { self.paginated.mapToArtist($0, mediaSourceId: mediaSourceId) }),
                paginationContext: response.paginationContext
            )
        case .playlists:
            let response = SearchPlaylistsResponse(jsResult)
            return SearchResponse(
                result: .playlists(response.items.map { self.paginated.mapToTracklist($0, mediaSourceId: mediaSourceId, tracklistType: .playlist) }),
                paginationContext: response.paginationContext
            )
        }
    }
}
