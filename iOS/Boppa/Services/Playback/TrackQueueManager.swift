import Foundation
import os

@Observable
final class QueueNode {
    let track: Track
    var isSelected: Bool = false
    var next: QueueNode?
    weak var prev: QueueNode?

    init(track: Track) {
        self.track = track
    }
}

@Observable
@MainActor
final class TrackQueueManager {
    static let shared = TrackQueueManager()

    // Stored for @Observable reactivity; kept in sync with the DLL via syncStoredProperties()
    private(set) var queue: [Track] = []
    private(set) var currentIndex: Int = 0
    private(set) var repeatMode: RepeatMode = .off

    /// Maps original display-list index → node. Built at setQueue time; stable through reorders.
    /// Views use nodeByDisplayIndex[rowIndex]?.isSelected to determine highlight state.
    private(set) var nodeByDisplayIndex: [Int: QueueNode] = [:]

    private var head: QueueNode?
    private var tail: QueueNode?
    private(set) var currentNode: QueueNode? {
        didSet {
            oldValue?.isSelected = false
            self.currentNode?.isSelected = true
        }
    }

    var currentTrack: Track? {
        self.currentNode?.track
    }

    var displayQueue: [Track] {
        switch self.repeatMode {
        case .one:
            return self.currentNode.map { [$0.track] } ?? []
        case .all, .off:
            return self.queue
        }
    }

    private static let artworkPreloadWindow = 50

    private let registry = WebViewPlaybackEngineRegistry.shared
    private var preloadedArtworkUrls: Set<String> = []

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Boppa",
        category: "TrackQueueManager"
    )

    private init() {}

    // MARK: - Queue Setup

    func setQueue(_ tracks: [Track], startingAt index: Int) {
        self.head = nil
        self.tail = nil
        self.currentNode = nil
        self.nodeByDisplayIndex = [:]

        var prev: QueueNode?
        for (i, track) in tracks.enumerated() {
            let node = QueueNode(track: track)
            node.prev = prev
            prev?.next = node
            if self.head == nil { self.head = node }
            self.tail = node
            self.nodeByDisplayIndex[i] = node
            prev = node
        }

        self.currentNode = self.nodeByDisplayIndex[index]
        self.syncStoredProperties()
        self.updateArtworkPreloads()
    }

    func setQueue(_ tracks: [Track], startingAt track: Track) {
        self.setQueue(tracks, startingAt: tracks.firstIndex(of: track) ?? 0)
    }

    // MARK: - Playback navigation

    func advanceToNext() -> Track? {
        guard self.head != nil else { return nil }

        if self.repeatMode == .one { return self.currentTrack }

        if let next = self.currentNode?.next {
            self.currentNode = next
        } else if self.repeatMode == .all {
            self.currentNode = self.head
        } else {
            return nil
        }

        self.syncStoredProperties()
        self.updateArtworkPreloads()
        return self.currentTrack
    }

    func rewindToPrevious() -> Track? {
        guard self.head != nil else { return nil }

        if let prev = self.currentNode?.prev {
            self.currentNode = prev
        } else if self.repeatMode == .all {
            self.currentNode = self.tail
        } else {
            return nil
        }

        self.syncStoredProperties()
        self.updateArtworkPreloads()
        return self.currentTrack
    }

    // MARK: - Queue Mutation

    func addToQueue(_ track: Track) {
        let node = QueueNode(track: track)
        self.append(node)
        self.syncStoredProperties()
        self.updateArtworkPreloads()
    }

    func playNext(_ track: Track) {
        let node = QueueNode(track: track)
        if let current = self.currentNode {
            self.insert(node, after: current)
        } else {
            self.append(node)
        }
        self.syncStoredProperties()
        self.updateArtworkPreloads()
    }

    func removeFromQueue(at index: Int) {
        guard index >= 0, index < self.queue.count, index != self.currentIndex else { return }
        if let node = self.node(at: index) {
            self.unlink(node)
        }
        self.syncStoredProperties()
        self.updateArtworkPreloads()
    }

    func removeTracks(forMediaSource mediaSourceId: String) {
        var node = self.head
        while let n = node {
            let next = n.next
            if n.track.mediaSourceId == mediaSourceId {
                if n === self.currentNode { self.currentNode = next ?? self.head }
                self.unlink(n)
            }
            node = next
        }
        self.syncStoredProperties()
    }

    func clearQueue() {
        self.currentNode = nil
        self.head = nil
        self.tail = nil
        self.nodeByDisplayIndex = [:]
        self.queue = []
        self.currentIndex = 0
        self.preloadedArtworkUrls = []
    }

    func moveQueueItem(fromOffsets source: IndexSet, toOffset destination: Int) {
        var nodes = self.allNodes()
        let moving = source.map { nodes[$0] }

        for index in source.sorted().reversed() {
            nodes.remove(at: index)
        }

        let adjustment = source.filter { $0 < destination }.count
        nodes.insert(contentsOf: moving, at: destination - adjustment)

        self.relink(nodes)
        self.syncStoredProperties()
        self.updateArtworkPreloads()
    }

    func applyReorderedDisplayQueue(_ reorderedDisplay: [Track]) {
        guard self.repeatMode != .one else { return }

        var remaining = self.allNodes()
        var ordered: [QueueNode] = []
        for track in reorderedDisplay {
            if let idx = remaining.firstIndex(where: { $0.track == track }) {
                ordered.append(remaining.remove(at: idx))
            }
        }

        self.relink(ordered)
        self.syncStoredProperties()
    }

    // MARK: - Repeat

    func clearRepeatOne() {
        if self.repeatMode == .one { self.repeatMode = .off }
    }

    func cycleRepeatMode() {
        switch self.repeatMode {
        case .off: self.repeatMode = .all
        case .all: self.repeatMode = .one
        case .one: self.repeatMode = .off
        }
    }

    // MARK: - DLL Helpers

    private func append(_ node: QueueNode) {
        node.prev = self.tail
        node.next = nil
        self.tail?.next = node
        self.tail = node
        if self.head == nil {
            self.head = node
            self.currentNode = node
        }
    }

    private func insert(_ node: QueueNode, after anchor: QueueNode) {
        let next = anchor.next
        node.prev = anchor
        node.next = next
        anchor.next = node
        next?.prev = node
        if anchor === self.tail { self.tail = node }
    }

    private func unlink(_ node: QueueNode) {
        node.prev?.next = node.next
        node.next?.prev = node.prev
        if node === self.head { self.head = node.next }
        if node === self.tail { self.tail = node.prev }
        node.next = nil
        node.prev = nil
    }

    private func node(at index: Int) -> QueueNode? {
        var i = 0
        var node = self.head
        while let n = node {
            if i == index { return n }
            i += 1
            node = n.next
        }
        return nil
    }

    private func allNodes() -> [QueueNode] {
        var result: [QueueNode] = []
        var node = self.head
        while let n = node {
            result.append(n)
            node = n.next
        }
        return result
    }

    private func relink(_ nodes: [QueueNode]) {
        self.head = nodes.first
        self.tail = nodes.last
        for (i, n) in nodes.enumerated() {
            n.prev = i > 0 ? nodes[i - 1] : nil
            n.next = i < nodes.count - 1 ? nodes[i + 1] : nil
        }
    }

    /// Rebuilds queue:[Track] and currentIndex from the DLL for @Observable reactivity.
    private func syncStoredProperties() {
        var result: [Track] = []
        var idx = 0
        var foundIndex = 0
        var node = self.head
        while let n = node {
            result.append(n.track)
            if n === self.currentNode { foundIndex = idx }
            idx += 1
            node = n.next
        }
        self.queue = result
        self.currentIndex = foundIndex
    }

    // MARK: - Artwork Preloading

    private func updateArtworkPreloads() {
        guard !self.queue.isEmpty else { return }

        let window = Self.artworkPreloadWindow
        let startIndex = max(0, self.currentIndex - window)
        let endIndex = min(self.queue.count - 1, self.currentIndex + window)

        var desiredUrls: Set<String> = []
        for i in startIndex ... endIndex {
            if let remoteUrl = self.queue[i].artworkUrl,
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
