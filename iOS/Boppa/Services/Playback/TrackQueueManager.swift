import Foundation

@Observable
final class QueueEntry: Identifiable {
    let id = UUID()
    let track: Track
    let userAdded: Bool

    init(track: Track, userAdded: Bool = false) {
        self.track = track
        self.userAdded = userAdded
    }
}

@Observable
@MainActor
final class TrackQueueManager {
    static let shared = TrackQueueManager()

    private(set) var entries: [QueueEntry] = []
    private(set) var currentIndex: Int = 0

    private(set) var repeatMode: RepeatMode = .all
    private(set) var contextId: String?

    private(set) var trackIdToEntry: [UUID: QueueEntry] = [:]

    var currentEntry: QueueEntry? {
        guard !self.entries.isEmpty, self.currentIndex >= 0, self.currentIndex < self.entries.count else { return nil }
        return self.entries[self.currentIndex]
    }

    var currentTrack: Track? {
        self.currentEntry?.track
    }

    var queue: [Track] {
        self.entries.map(\.track)
    }

    private static let artworkPreloadWindow = 50

    private let registry = WebViewPlaybackEngineRegistry.shared
    private var preloadedArtworkUrls: Set<String> = []

    private init() {}

    func setQueue(_ tracks: [Track], startingAt index: Int, contextId: String) {
        self.contextId = contextId
        self.entries = tracks.map { QueueEntry(track: $0) }
        self.rebuildTrackIdMap()
        self.currentIndex = min(max(index, 0), max(self.entries.count - 1, 0))
        self.updateArtworkPreloads()
    }

    func jump(to entry: QueueEntry) {
        guard let index = self.entries.firstIndex(where: { $0.id == entry.id }) else { return }
        self.currentIndex = index
        self.updateArtworkPreloads()
    }

    func advanceToNext() -> Track? {
        guard !self.entries.isEmpty else { return nil }

        if self.repeatMode == .one { return self.currentTrack }

        if self.currentIndex + 1 < self.entries.count {
            self.currentIndex += 1
        } else if self.repeatMode == .all {
            self.currentIndex = 0
        } else {
            return nil
        }

        self.updateArtworkPreloads()
        return self.currentTrack
    }

    func rewindToPrevious() -> Track? {
        guard !self.entries.isEmpty else { return nil }

        if self.currentIndex - 1 >= 0 {
            self.currentIndex -= 1
        } else if self.repeatMode == .all {
            self.currentIndex = self.entries.count - 1
        } else {
            return nil
        }

        self.updateArtworkPreloads()
        return self.currentTrack
    }

    // MARK: - Queue Mutation

    func playNext(_ track: Track) {
        let entry = QueueEntry(track: track, userAdded: true)
        let insertIndex = self.entries.isEmpty ? 0 : self.currentIndex + 1
        self.entries.insert(entry, at: insertIndex)
        self.trackIdToEntry[track.id] = entry
        self.updateArtworkPreloads()
    }

    func removeFromQueue(_ entry: QueueEntry) {
        guard let index = self.entries.firstIndex(where: { $0.id == entry.id }) else { return }
        guard index != self.currentIndex else { return }
        self.entries.remove(at: index)
        self.trackIdToEntry.removeValue(forKey: entry.track.id)
        if index < self.currentIndex {
            self.currentIndex -= 1
        }
        self.updateArtworkPreloads()
    }

    func removeTracks(forMediaSource mediaSourceId: String) {
        let currentId = self.currentEntry?.id
        let removed = self.entries.filter { $0.track.mediaSourceId == mediaSourceId }
        for entry in removed {
            self.trackIdToEntry.removeValue(forKey: entry.track.id)
        }
        self.entries.removeAll { $0.track.mediaSourceId == mediaSourceId }

        if let currentId, let newIndex = self.entries.firstIndex(where: { $0.id == currentId }) {
            self.currentIndex = newIndex
        } else {
            self.currentIndex = min(self.currentIndex, max(self.entries.count - 1, 0))
        }
    }

    func clearQueue() {
        self.entries = []
        self.currentIndex = 0
        self.contextId = nil
        self.trackIdToEntry = [:]
        self.preloadedArtworkUrls = []
    }

    func applyReorder(_ reorderedEntries: [QueueEntry]) {
        let currentId = self.currentEntry?.id
        self.entries = reorderedEntries
        if let currentId {
            self.currentIndex = self.entries.firstIndex(where: { $0.id == currentId }) ?? 0
        }
    }

    func clearRepeatOne() {
        if self.repeatMode == .one { self.repeatMode = .all }
    }

    func cycleRepeatMode() {
        switch self.repeatMode {
        case .all: self.repeatMode = .one
        case .one: self.repeatMode = .all
        }
    }

    func isTrackSelected(_ track: Track, contextId: String) -> Bool {
        guard self.contextId == contextId else { return false }
        guard let entry = self.trackIdToEntry[track.id] else { return false }
        return entry.id == self.currentEntry?.id
    }

    private func rebuildTrackIdMap() {
        self.trackIdToEntry = [:]
        for entry in self.entries {
            self.trackIdToEntry[entry.track.id] = entry
        }
    }

    private func updateArtworkPreloads() {
        guard !self.entries.isEmpty else { return }

        let window = Self.artworkPreloadWindow
        let startIndex = max(0, self.currentIndex - window)
        let endIndex = min(self.entries.count - 1, self.currentIndex + window)

        var desiredUrls: Set<String> = []
        for i in startIndex ... endIndex {
            if let remoteUrl = self.entries[i].track.artworkUrl,
               let localUrl = ArtworkServer.localURL(for: remoteUrl)
            {
                desiredUrls.insert(localUrl)
            }
        }

        let toAdd = desiredUrls.subtracting(self.preloadedArtworkUrls)
        let toRemove = self.preloadedArtworkUrls.subtracting(desiredUrls)

        let engines = self.registry.allEngines
        if !toAdd.isEmpty { engines.forEach { $0.preloadArtwork(urls: Array(toAdd)) } }
        if !toRemove.isEmpty { engines.forEach { $0.removeArtwork(urls: Array(toRemove)) } }

        self.preloadedArtworkUrls = desiredUrls
    }
}
