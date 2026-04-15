import Foundation
import os

@Observable
@MainActor
final class TrackQueueManager {
    static let shared = TrackQueueManager()

    private(set) var queue: [Track] = []
    private(set) var currentIndex: Int = 0
    private(set) var repeatMode: RepeatMode = .off

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "BopBrowser",
        category: "TrackQueueManager"
    )

    var currentTrack: Track? {
        guard !self.queue.isEmpty, self.currentIndex < self.queue.count else { return nil }
        return self.queue[self.currentIndex]
    }

    var displayQueue: [Track] {
        guard !self.queue.isEmpty, self.currentIndex < self.queue.count else {
            return self.queue
        }

        switch self.repeatMode {
        case .one:
            return [self.queue[self.currentIndex]]
        case .all, .off:
            return self.queue
        }
    }

    private init() {}

    func setQueue(_ tracks: [Track], startingAt track: Track) {
        self.queue = tracks
        self.currentIndex = tracks.firstIndex(of: track) ?? 0
    }

    func advanceToNext() -> Track? {
        guard !self.queue.isEmpty else { return nil }

        if self.repeatMode == .one {
            return self.currentTrack
        }

        let nextIndex = self.currentIndex + 1
        if nextIndex >= self.queue.count {
            if self.repeatMode == .all {
                self.currentIndex = 0
            } else {
                return nil
            }
        } else {
            self.currentIndex = nextIndex
        }

        return self.currentTrack
    }

    func rewindToPrevious() -> Track? {
        guard !self.queue.isEmpty else { return nil }

        if self.currentIndex > 0 {
            self.currentIndex -= 1
        } else if self.repeatMode == .all {
            self.currentIndex = self.queue.count - 1
        } else {
            return nil
        }

        return self.currentTrack
    }

    func addToQueue(_ track: Track) {
        self.queue.append(track)
    }

    func playNext(_ track: Track) {
        let insertIndex = self.currentIndex + 1
        if insertIndex >= self.queue.count {
            self.queue.append(track)
        } else {
            self.queue.insert(track, at: insertIndex)
        }
    }

    func removeFromQueue(at index: Int) {
        guard index >= 0, index < self.queue.count, index != self.currentIndex else { return }
        self.queue.remove(at: index)
        if index < self.currentIndex {
            self.currentIndex -= 1
        }
    }

    func removeTracks(forMediaSource mediaSourceId: String) {
        let current = self.currentTrack
        self.queue.removeAll { $0.mediaSourceId == mediaSourceId }
        if let current, let newIndex = self.queue.firstIndex(of: current) {
            self.currentIndex = newIndex
        } else {
            self.currentIndex = min(self.currentIndex, max(self.queue.count - 1, 0))
        }
    }

    func clearQueue() {
        self.queue = []
        self.currentIndex = 0
    }

    func moveQueueItem(fromOffsets source: IndexSet, toOffset destination: Int) {
        let current = self.currentTrack
        var reordered = self.queue
        let items = source.map { reordered[$0] }

        for index in source.sorted().reversed() {
            reordered.remove(at: index)
        }

        let adjustment = source.filter { $0 < destination }.count
        let insertionIndex = destination - adjustment
        reordered.insert(contentsOf: items, at: insertionIndex)
        self.queue = reordered

        if let current,
           let newIndex = self.queue.firstIndex(of: current)
        {
            self.currentIndex = newIndex
        }
    }

    func applyReorderedDisplayQueue(_ reorderedDisplay: [Track]) {
        guard self.repeatMode != .one else { return }

        let current = self.currentTrack
        self.queue = reorderedDisplay
        self.currentIndex = current.flatMap { track in self.queue.firstIndex(of: track) } ?? 0
    }

    func cycleRepeatMode() {
        switch self.repeatMode {
        case .off:
            self.repeatMode = .all
        case .all:
            self.repeatMode = .one
        case .one:
            self.repeatMode = .off
        }
    }
}
