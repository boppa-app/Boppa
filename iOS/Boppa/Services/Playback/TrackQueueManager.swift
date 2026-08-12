import Foundation
import Kingfisher

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
    private(set) var shuffledEntries: [QueueEntry] = []
    private(set) var shuffleMode: ShuffleMode = .off
    private(set) var currentIndex: Int = 0

    private(set) var repeatMode: RepeatMode = .off
    private(set) var contextId: String?

    private var preRadioQueueTail: [QueueEntry]?

    private let radioService = RadioService.shared

    var activeEntries: [QueueEntry] {
        self.shuffleMode == .shuffle ? self.shuffledEntries : self.entries
    }

    var currentEntry: QueueEntry? {
        let active = self.activeEntries
        guard !active.isEmpty, self.currentIndex >= 0, self.currentIndex < active.count else { return nil }
        return active[self.currentIndex]
    }

    var currentTrack: Track? {
        self.currentEntry?.track
    }

    var queue: [Track] {
        self.activeEntries.map(\.track)
    }

    private static let artworkPreloadWindow = 3

    private let registry = WebViewPlaybackEngineRegistry.shared
    private var preloadedArtworkBySource: [String: Set<String>] = [:]
    private let isTrackEnabled: (Track) -> Bool

    init(isTrackEnabled: @escaping (Track) -> Bool = { $0.isMediaSourceEnabled }) {
        self.isTrackEnabled = isTrackEnabled
        for name: Notification.Name in [.mediaSourceDisabled, .mediaSourceEnabled, .mediaSourceRemoved, .mediaSourceAdded] {
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.updateArtworkPreloads()
                }
            }
        }
    }

    // MARK: Selection

    func isTrackSelected(_ track: Track, contextId: String) -> Bool {
        guard self.contextId == contextId else { return false }
        return self.currentEntry?.track.trackKey == track.trackKey
    }

    // MARK: Navigation

    func setQueue(_ tracks: [Track], startingAt index: Int, contextId: String) {
        self.contextId = contextId
        self.entries = tracks.map { QueueEntry(track: $0) }
        self.preRadioQueueTail = nil
        if self.shuffleMode == .radio {
            self.shuffleMode = .off
        }
        let clampedIndex = min(max(index, 0), max(self.entries.count - 1, 0))
        if self.shuffleMode == .shuffle {
            let anchor = self.entries.indices.contains(clampedIndex) ? self.entries[clampedIndex] : nil
            self.rebuildShuffledEntries(anchoredAt: anchor)
            self.currentIndex = 0
        } else {
            self.shuffledEntries = []
            self.currentIndex = clampedIndex
        }
        self.updateArtworkPreloads()
    }

    func jump(to entry: QueueEntry) {
        guard let index = self.activeEntries.firstIndex(where: { $0.id == entry.id }) else { return }
        self.currentIndex = index
        self.updateArtworkPreloads()
    }

    func advanceToNext() async -> Track? {
        if let nextTrack = self.advanceWithinQueue() {
            return nextTrack
        }
        guard self.shuffleMode == .radio, !self.radioService.isExhausted, let seedTrack = self.currentTrack
        else { return nil }
        await self.fetchRadioBatch(seedTrack: seedTrack)
        return self.advanceWithinQueue()
    }

    private func advanceWithinQueue() -> Track? {
        let active = self.activeEntries
        guard !active.isEmpty else { return nil }

        if self.repeatMode == .one { return self.currentTrack }

        let startIndex = self.currentIndex
        var nextIndex = startIndex

        while true {
            if nextIndex + 1 < active.count {
                nextIndex += 1
            } else if self.repeatMode == .all {
                nextIndex = 0
            } else {
                return nil
            }

            if nextIndex == startIndex { return nil }

            if self.isTrackEnabled(active[nextIndex].track) {
                self.currentIndex = nextIndex
                self.updateArtworkPreloads()
                return self.currentTrack
            }
        }
    }

    func rewindToPrevious() -> Track? {
        let active = self.activeEntries
        guard !active.isEmpty else { return nil }

        let startIndex = self.currentIndex
        var prevIndex = startIndex

        while true {
            if prevIndex - 1 >= 0 {
                prevIndex -= 1
            } else if self.repeatMode == .all {
                prevIndex = active.count - 1
            } else {
                return nil
            }

            if prevIndex == startIndex { return nil }

            if self.isTrackEnabled(active[prevIndex].track) {
                self.currentIndex = prevIndex
                self.updateArtworkPreloads()
                return self.currentTrack
            }
        }
    }

    // MARK: - Queue Mutation

    func playNext(_ track: Track) {
        let entry = QueueEntry(track: track, userAdded: true)
        self.entries.insert(entry, at: self.insertionIndexAfterCurrent(in: self.entries))
        self.shuffledEntries.insert(entry, at: self.insertionIndexAfterCurrent(in: self.shuffledEntries))
        self.updateArtworkPreloads()
    }

    private func insertionIndexAfterCurrent(in array: [QueueEntry]) -> Int {
        guard !array.isEmpty else { return 0 }
        guard let currentId = self.currentEntry?.id, let idx = array.firstIndex(where: { $0.id == currentId }) else {
            return array.count
        }
        return idx + 1
    }

    func addToQueue(_ track: Track) {
        let entry = QueueEntry(track: track, userAdded: true)
        self.entries.insert(entry, at: self.insertionIndexAfterLastUserAdded(in: self.entries))
        self.shuffledEntries.insert(entry, at: self.insertionIndexAfterLastUserAdded(in: self.shuffledEntries))
        self.updateArtworkPreloads()
    }

    private func insertionIndexAfterLastUserAdded(in array: [QueueEntry]) -> Int {
        array.lastIndex(where: \.userAdded).map { $0 + 1 } ?? self.insertionIndexAfterCurrent(in: array)
    }

    func removeFromQueue(_ entry: QueueEntry) {
        guard let activeIndex = self.activeEntries.firstIndex(where: { $0.id == entry.id }) else { return }
        guard activeIndex != self.currentIndex else { return }

        self.entries.removeAll { $0.id == entry.id }
        self.shuffledEntries.removeAll { $0.id == entry.id }

        if activeIndex < self.currentIndex {
            self.currentIndex -= 1
        }
        self.updateArtworkPreloads()
    }

    func clearQueue() {
        self.entries = []
        self.shuffledEntries = []
        self.currentIndex = 0
        self.contextId = nil
        self.preloadedArtworkBySource = [:]
    }

    func applyReorder(_ reorderedEntries: [QueueEntry]) {
        let currentId = self.currentEntry?.id
        if self.shuffleMode == .shuffle {
            let disabledEntries = self.shuffledEntries.filter { !self.isTrackEnabled($0.track) }
            self.shuffledEntries = reorderedEntries + disabledEntries
        } else {
            let disabledEntries = self.entries.filter { !self.isTrackEnabled($0.track) }
            self.entries = reorderedEntries + disabledEntries
        }
        if let currentId {
            self.currentIndex = self.activeEntries.firstIndex(where: { $0.id == currentId }) ?? 0
        }
    }

    func cycleShuffleMode() async {
        let radioAvailable = self.currentTrack.flatMap {
            MediaSourceStorageManager.shared.fetchOne(id: $0.mediaSourceId)
        }?.config.data.list?.trackRadio != nil

        switch self.shuffleMode {
        case .off:
            self.setShuffleMode(.shuffle)
        case .shuffle:
            self.setShuffleMode(radioAvailable ? .radio : .off)
        case .radio:
            self.setShuffleMode(.off)
        }
        if self.shuffleMode == .radio {
            await self.primeRadioIfNeeded()
        }
    }

    func setShuffleMode(_ mode: ShuffleMode) {
        guard mode != self.shuffleMode else { return }
        let anchor = self.currentEntry
        let wasRadio = self.shuffleMode == .radio
        self.shuffleMode = mode

        if wasRadio, mode != .radio {
            self.restorePreRadioQueueTail()
        }

        switch mode {
        case .shuffle:
            self.rebuildShuffledEntries(anchoredAt: anchor)
            self.currentIndex = 0
        case .off, .radio:
            self.clearShuffledEntries(reanchoringTo: anchor)
        }

        if mode == .radio {
            self.truncateQueueForRadio()
            self.radioService.reset()
        }

        self.updateArtworkPreloads()
    }

    private func rebuildShuffledEntries(anchoredAt anchor: QueueEntry?) {
        var pool = self.entries
        if self.repeatMode == .off, let anchor, let anchorIdx = pool.firstIndex(where: { $0.id == anchor.id }) {
            pool = Array(pool[anchorIdx...])
        }

        var anchored: [QueueEntry] = []
        if let anchor, let idx = pool.firstIndex(where: { $0.id == anchor.id }) {
            anchored.append(pool.remove(at: idx))
        }
        let userAdded = pool.filter(\.userAdded)
        let rest = pool.filter { !$0.userAdded }
        self.shuffledEntries = anchored + userAdded + rest.shuffled()
    }

    private func restorePreRadioQueueTail() {
        guard let tail = self.preRadioQueueTail else { return }
        let keepCount = min(self.currentIndex + 1, self.entries.count)
        self.entries = Array(self.entries.prefix(keepCount)) + tail
        self.preRadioQueueTail = nil
    }

    private func clearShuffledEntries(reanchoringTo anchor: QueueEntry?) {
        self.shuffledEntries = []
        self.currentIndex = anchor.flatMap { entry in self.entries.firstIndex(where: { $0.id == entry.id }) } ?? 0
    }

    private func truncateQueueForRadio() {
        self.preRadioQueueTail = self.currentIndex + 1 < self.entries.count
            ? Array(self.entries[(self.currentIndex + 1)...]) : []
        if self.currentIndex + 1 < self.entries.count {
            self.entries.removeSubrange((self.currentIndex + 1)...)
        }
    }

    func appendTracks(_ tracks: [Track]) {
        guard !tracks.isEmpty else { return }
        self.entries.append(contentsOf: tracks.map { QueueEntry(track: $0) })
        self.updateArtworkPreloads()
    }

    // MARK: - Radio

    func primeRadioIfNeeded() async {
        guard !self.radioService.hasPrimedPages, let seedTrack = self.currentTrack else { return }
        await self.fetchRadioBatch(seedTrack: seedTrack)
        guard self.shuffleMode == .radio, !self.radioService.isExhausted else { return }
        await self.fetchRadioBatch(seedTrack: seedTrack)
    }

    func topUpRadioIfNeeded() {
        guard self.shuffleMode == .radio, !self.radioService.isFetchingRadio else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            if !self.radioService.hasPrimedPages {
                await self.primeRadioIfNeeded()
            } else {
                await self.topUpRadioWhileOnLastPage()
            }
        }
    }

    private func topUpRadioWhileOnLastPage() async {
        while self.shuffleMode == .radio,
              self.radioService.shouldTopUp(currentIndex: self.currentIndex),
              let seedTrack = self.currentTrack
        {
            guard await self.fetchRadioBatch(seedTrack: seedTrack) else { break }
        }
    }

    @discardableResult
    private func fetchRadioBatch(seedTrack: Track) async -> Bool {
        guard let tracks = await self.radioService.fetchTracks(seedTrack: seedTrack, appendingAt: self.entries.count)
        else { return false }
        guard self.shuffleMode == .radio else { return false }

        if !tracks.isEmpty {
            self.appendTracks(tracks)
        }
        return true
    }

    // MARK: Repeat Mode

    func exitRepeatOneOnUserSkip() {
        guard self.repeatMode == .one else { return }
        self.repeatMode = .all
        self.handleRepeatModeChanged()
    }

    func cycleRepeatMode() {
        switch self.repeatMode {
        case .off: self.repeatMode = .all
        case .all: self.repeatMode = .one
        case .one: self.repeatMode = .off
        }
        self.handleRepeatModeChanged()
    }

    private func handleRepeatModeChanged() {
        guard self.shuffleMode == .shuffle else { return }
        let anchor = self.currentEntry
        self.rebuildShuffledEntries(anchoredAt: anchor)
        self.currentIndex = 0
        self.updateArtworkPreloads()
    }

    // MARK: Artwork Preloading

    private func updateArtworkPreloads() {
        let entries = self.activeEntries
        guard !entries.isEmpty else { return }

        let desiredBySource = self.desiredArtworkUrlsBySource(in: entries)

        self.prefetchNewArtworkGlobally(desiredBySource)
        self.syncEngineArtworkPreloads(desiredBySource)

        self.preloadedArtworkBySource = desiredBySource
    }

    private func desiredArtworkUrlsBySource(in entries: [QueueEntry]) -> [String: Set<String>] {
        var desiredBySource: [String: Set<String>] = [:]

        func collect(_ indices: some Sequence<Int>) {
            var count = 0
            for i in indices {
                let track = entries[i].track
                guard self.isTrackEnabled(track) else { continue }
                for url in [track.lowResArtworkUrl, track.highResArtworkUrl] {
                    if let url, !url.isEmpty {
                        desiredBySource[track.mediaSourceId, default: []].insert(url)
                    }
                }
                count += 1
                if count >= Self.artworkPreloadWindow { break }
            }
        }

        collect(self.currentIndex ..< entries.count)
        collect(stride(from: self.currentIndex - 1, through: 0, by: -1))

        return desiredBySource
    }

    private func prefetchNewArtworkGlobally(_ desiredBySource: [String: Set<String>]) {
        let desiredUrls = Set(desiredBySource.values.joined())
        let previousUrls = Set(self.preloadedArtworkBySource.values.joined())
        let toAddGlobal = desiredUrls.subtracting(previousUrls)
        guard !toAddGlobal.isEmpty else { return }
        ImagePrefetcher(urls: toAddGlobal.compactMap { URL(string: $0) }).start()
    }

    private func syncEngineArtworkPreloads(_ desiredBySource: [String: Set<String>]) {
        for (mediaSourceId, desired) in desiredBySource {
            guard let engine = self.registry.engine(for: mediaSourceId) else { continue }
            let previous = self.preloadedArtworkBySource[mediaSourceId] ?? []
            let toAdd = desired.subtracting(previous)
            let toRemove = previous.subtracting(desired)
            if !toAdd.isEmpty { engine.preloadArtwork(urls: Array(toAdd)) }
            if !toRemove.isEmpty { engine.removeArtwork(urls: Array(toRemove)) }
        }

        for (mediaSourceId, previous) in self.preloadedArtworkBySource where desiredBySource[mediaSourceId] == nil {
            guard let engine = self.registry.engine(for: mediaSourceId) else { continue }
            engine.removeArtwork(urls: Array(previous))
        }
    }
}
