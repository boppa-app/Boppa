import Foundation
import os

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "Boppa",
    category: "RadioService"
)

@Observable
@MainActor
final class RadioService {
    static let shared = RadioService()

    private(set) var isFetchingRadio = false
    private(set) var radioError: String?
    private(set) var isExhausted = false

    private var continuation: [String: Any]?
    private var pageStartIndices: [Int] = []

    private init() {}

    var hasPrimedPages: Bool {
        !self.pageStartIndices.isEmpty
    }

    func shouldTopUp(currentIndex: Int) -> Bool {
        guard !self.isExhausted,
              let lastPageStart = self.pageStartIndices.last else { return false }
        return currentIndex >= lastPageStart
    }

    func reset() {
        self.continuation = nil
        self.isExhausted = false
        self.radioError = nil
        self.pageStartIndices = []
    }

    @discardableResult
    func fetchTracks(seedTrack: Track, appendingAt entryCount: Int) async -> [Track]? {
        guard !self.isFetchingRadio else { return nil }
        guard let mediaSource = MediaSourceStorageManager.shared
            .fetchOne(id: seedTrack.mediaSourceId)
        else { return nil }

        self.isFetchingRadio = true
        self.radioError = nil
        defer { self.isFetchingRadio = false }

        do {
            let response = try await TracklistFetchService.shared.fetchTrackRadio(
                seedMediaId: seedTrack.mediaId,
                seedType: seedTrack.type,
                mediaSource: mediaSource,
                previousResult: self.continuation
            )
            logger.info("Radio: fetched \(response.tracks.count) track(s)")
            if !response.tracks.isEmpty {
                self.pageStartIndices.append(entryCount)
            }
            self.continuation = response.continuation
            self.isExhausted = response.continuation == nil
            return response.tracks
        } catch {
            logger.error("Radio fetch failed: \(error)")
            self.radioError = error.localizedDescription
            return nil
        }
    }
}
