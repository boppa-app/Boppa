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

    private(set) var trackIdToEntry: [String: QueueEntry] = [:]

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
    private var preloadedArtworkBySource: [String: Set<String>] = [:]

    private init() {
        for name: Notification.Name in [.mediaSourceDisabled, .mediaSourceEnabled, .mediaSourceRemoved, .mediaSourceAdded] {
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.updateArtworkPreloads()
                }
            }
        }
    }

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

        let startIndex = self.currentIndex
        var nextIndex = startIndex

        while true {
            if nextIndex + 1 < self.entries.count {
                nextIndex += 1
            } else if self.repeatMode == .all {
                nextIndex = 0
            } else {
                return nil
            }

            if nextIndex == startIndex { return nil }

            if self.entries[nextIndex].track.isMediaSourceEnabled {
                self.currentIndex = nextIndex
                self.updateArtworkPreloads()
                return self.currentTrack
            }
        }
    }

    func rewindToPrevious() -> Track? {
        guard !self.entries.isEmpty else { return nil }

        let startIndex = self.currentIndex
        var prevIndex = startIndex

        while true {
            if prevIndex - 1 >= 0 {
                prevIndex -= 1
            } else if self.repeatMode == .all {
                prevIndex = self.entries.count - 1
            } else {
                return nil
            }

            if prevIndex == startIndex { return nil }

            if self.entries[prevIndex].track.isMediaSourceEnabled {
                self.currentIndex = prevIndex
                self.updateArtworkPreloads()
                return self.currentTrack
            }
        }
    }

    // MARK: - Queue Mutation

    func playNext(_ track: Track) {
        let entry = QueueEntry(track: track, userAdded: true)
        let insertIndex = self.entries.isEmpty ? 0 : self.currentIndex + 1
        self.entries.insert(entry, at: insertIndex)
        self.trackIdToEntry[track.trackKey] = entry
        self.updateArtworkPreloads()
    }

    func removeFromQueue(_ entry: QueueEntry) {
        guard let index = self.entries.firstIndex(where: { $0.id == entry.id }) else { return }
        guard index != self.currentIndex else { return }
        self.entries.remove(at: index)
        self.trackIdToEntry.removeValue(forKey: entry.track.trackKey)
        if index < self.currentIndex {
            self.currentIndex -= 1
        }
        self.updateArtworkPreloads()
    }

    func clearQueue() {
        self.entries = []
        self.currentIndex = 0
        self.contextId = nil
        self.trackIdToEntry = [:]
        self.preloadedArtworkBySource = [:]
    }

    func applyReorder(_ reorderedEntries: [QueueEntry]) {
        let currentId = self.currentEntry?.id
        let disabledEntries = self.entries.filter { !$0.track.isMediaSourceEnabled }
        self.entries = reorderedEntries + disabledEntries
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
        guard let entry = self.trackIdToEntry[track.trackKey] else { return false }
        return entry.id == self.currentEntry?.id
    }

    private func rebuildTrackIdMap() {
        self.trackIdToEntry = [:]
        for entry in self.entries {
            self.trackIdToEntry[entry.track.trackKey] = entry
        }
    }

    private func updateArtworkPreloads() {
        guard !self.entries.isEmpty else { return }

        let window = Self.artworkPreloadWindow

        var desiredBySource: [String: Set<String>] = [:]

        var count = 0
        for i in self.currentIndex ..< self.entries.count {
            let track = self.entries[i].track
            guard track.isMediaSourceEnabled else { continue }
            if let url = track.artworkUrl, !url.isEmpty {
                desiredBySource[track.mediaSourceId, default: []].insert(url)
            }
            count += 1
            if count >= window { break }
        }

        count = 0
        for i in stride(from: self.currentIndex - 1, through: 0, by: -1) {
            let track = self.entries[i].track
            guard track.isMediaSourceEnabled else { continue }
            if let url = track.artworkUrl, !url.isEmpty {
                desiredBySource[track.mediaSourceId, default: []].insert(url)
            }
            count += 1
            if count >= window { break }
        }

        for (mediaSourceId, desiredUrls) in desiredBySource {
            guard let engine = self.registry.engine(for: mediaSourceId) else { continue }
            let previousUrls = self.preloadedArtworkBySource[mediaSourceId] ?? []
            let toAdd = desiredUrls.subtracting(previousUrls)
            let toRemove = previousUrls.subtracting(desiredUrls)
            if !toAdd.isEmpty { engine.preloadArtwork(urls: Array(toAdd)) }
            if !toRemove.isEmpty { engine.removeArtwork(urls: Array(toRemove)) }
        }

        for (mediaSourceId, previousUrls) in self.preloadedArtworkBySource where desiredBySource[mediaSourceId] == nil {
            guard let engine = self.registry.engine(for: mediaSourceId) else { continue }
            engine.removeArtwork(urls: Array(previousUrls))
        }

        self.preloadedArtworkBySource = desiredBySource
    }
}
