import Foundation
import os

@Observable
@MainActor
final class SongQueueManager {
    static let shared = SongQueueManager()

    private(set) var queue: [Song] = []
    private(set) var currentIndex: Int = 0
    private(set) var repeatMode: RepeatMode = .off

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "BopBrowser",
        category: "SongQueueManager"
    )

    var currentTrack: Song? {
        guard !self.queue.isEmpty, self.currentIndex < self.queue.count else { return nil }
        return self.queue[self.currentIndex]
    }

    var displayQueue: [Song] {
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

    func setQueue(_ songs: [Song], startingAt track: Song) {
        self.queue = songs
        self.currentIndex = songs.firstIndex(of: track) ?? 0
    }

    func advanceToNext() -> Song? {
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

    func rewindToPrevious() -> Song? {
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

    func addToQueue(_ song: Song) {
        self.queue.append(song)
    }

    func playNext(_ song: Song) {
        let insertIndex = self.currentIndex + 1
        if insertIndex >= self.queue.count {
            self.queue.append(song)
        } else {
            self.queue.insert(song, at: insertIndex)
        }
    }

    func removeFromQueue(at index: Int) {
        guard index >= 0, index < self.queue.count, index != self.currentIndex else { return }
        self.queue.remove(at: index)
        if index < self.currentIndex {
            self.currentIndex -= 1
        }
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

    func applyReorderedDisplayQueue(_ reorderedDisplay: [Song]) {
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
