@testable import Boppa
internal import Foundation
import Testing

@MainActor
struct TrackQueueManagerTests {
    // MARK: - Fixtures

    private static let disabledSource = "disabled-source"

    private func track(_ id: String, source: String = "src") -> Track {
        Track(mediaId: id, mediaSourceId: source, title: id)
    }

    private func keys(_ tracks: [Track]) -> [String] {
        tracks.map(\.trackKey)
    }

    private func entryKeys(_ entries: [QueueEntry]) -> [String] {
        entries.map(\.track.trackKey)
    }

    private func toggleShuffle(_ manager: TrackQueueManager) {
        manager.setShuffleMode(manager.shuffleMode == .shuffle ? .off : .shuffle)
    }

    /// All tracks are enabled by default; pass disabledSources to mark specific media sources
    /// as disabled, mirroring Track.isMediaSourceEnabled without touching a real database
    private func makeManager(disabledSources: Set<String> = []) -> TrackQueueManager {
        TrackQueueManager(isTrackEnabled: { !disabledSources.contains($0.mediaSourceId) })
    }

    // MARK: - setQueue

    @Test func setQueueSetsEntriesAndCurrentIndex() {
        let manager = self.makeManager()
        let tracks = [self.track("a"), self.track("b"), self.track("c")]

        manager.setQueue(tracks, startingAt: 1, contextId: "ctx")

        #expect(self.entryKeys(manager.entries) == self.keys(tracks))
        #expect(manager.currentIndex == 1)
        #expect(manager.currentTrack?.trackKey == tracks[1].trackKey)
        #expect(manager.contextId == "ctx")
    }

    @Test func setQueueClampsNegativeStartIndex() {
        let manager = self.makeManager()

        manager.setQueue([self.track("a"), self.track("b")], startingAt: -5, contextId: "ctx")

        #expect(manager.currentIndex == 0)
    }

    @Test func setQueueClampsOutOfBoundsStartIndex() {
        let manager = self.makeManager()

        manager.setQueue([self.track("a"), self.track("b")], startingAt: 99, contextId: "ctx")

        #expect(manager.currentIndex == 1)
    }

    @Test func setQueueWithEmptyTracksResultsInNilCurrentTrack() {
        let manager = self.makeManager()

        manager.setQueue([], startingAt: 0, contextId: "ctx")

        #expect(manager.currentTrack == nil)
        #expect(manager.currentIndex == 0)
    }

    // MARK: - isTrackSelected

    @Test func isTrackSelectedMatchesCurrentTrackInMatchingContext() {
        let manager = self.makeManager()
        let a = self.track("a")
        let b = self.track("b")
        manager.setQueue([a, b], startingAt: 0, contextId: "ctx")

        #expect(manager.isTrackSelected(a, contextId: "ctx") == true)
        #expect(manager.isTrackSelected(b, contextId: "ctx") == false)
    }

    @Test func isTrackSelectedFalseForDifferentContext() {
        let manager = self.makeManager()
        let a = self.track("a")

        manager.setQueue([a], startingAt: 0, contextId: "ctx")

        #expect(manager.isTrackSelected(a, contextId: "other-ctx") == false)
    }

    // MARK: - jump

    @Test func jumpMovesCurrentIndexToTappedEntry() {
        let manager = self.makeManager()
        let tracks = [self.track("a"), self.track("b"), self.track("c")]
        manager.setQueue(tracks, startingAt: 0, contextId: "ctx")

        manager.jump(to: manager.entries[2])

        #expect(manager.currentIndex == 2)
        #expect(manager.currentTrack?.trackKey == tracks[2].trackKey)
    }

    @Test func jumpIgnoresUnknownEntry() {
        let manager = self.makeManager()
        manager.setQueue([self.track("a"), self.track("b")], startingAt: 0, contextId: "ctx")

        let bogus = QueueEntry(track: self.track("z"))
        manager.jump(to: bogus)

        #expect(manager.currentIndex == 0)
    }

    // MARK: - advanceToNext / rewindToPrevious (repeat off)

    @Test func advanceToNextRepeatOffMovesForwardAndStopsAtEnd() async {
        let manager = self.makeManager()
        let tracks = [self.track("a"), self.track("b"), self.track("c")]
        manager.setQueue(tracks, startingAt: 0, contextId: "ctx")

        #expect(await manager.advanceToNext()?.trackKey == tracks[1].trackKey)
        #expect(await manager.advanceToNext()?.trackKey == tracks[2].trackKey)
        #expect(await manager.advanceToNext() == nil)
        #expect(manager.currentIndex == 2)
    }

    @Test func rewindToPreviousRepeatOffMovesBackwardAndStopsAtStart() {
        let manager = self.makeManager()
        let tracks = [self.track("a"), self.track("b"), self.track("c")]
        manager.setQueue(tracks, startingAt: 2, contextId: "ctx")

        #expect(manager.rewindToPrevious()?.trackKey == tracks[1].trackKey)
        #expect(manager.rewindToPrevious()?.trackKey == tracks[0].trackKey)
        #expect(manager.rewindToPrevious() == nil)
        #expect(manager.currentIndex == 0)
    }

    @Test func advanceToNextSkipsDisabledTracks() async {
        let manager = self.makeManager(disabledSources: [Self.disabledSource])
        let a = self.track("a")
        let b = self.track("b", source: Self.disabledSource)
        let c = self.track("c")
        manager.setQueue([a, b, c], startingAt: 0, contextId: "ctx")

        #expect(await manager.advanceToNext()?.trackKey == c.trackKey)
        #expect(manager.currentIndex == 2)
    }

    @Test func advanceToNextRepeatOffAllRemainingDisabledReturnsNil() async {
        let manager = self.makeManager(disabledSources: [Self.disabledSource])
        let a = self.track("a")
        let b = self.track("b", source: Self.disabledSource)
        let c = self.track("c", source: Self.disabledSource)
        manager.setQueue([a, b, c], startingAt: 0, contextId: "ctx")

        #expect(await manager.advanceToNext() == nil)
        #expect(manager.currentIndex == 0)
    }

    // MARK: - repeat all

    @Test func advanceToNextRepeatAllWrapsAroundToStart() async {
        let manager = self.makeManager()
        let tracks = [self.track("a"), self.track("b"), self.track("c")]
        manager.setQueue(tracks, startingAt: 2, contextId: "ctx")
        manager.cycleRepeatMode()

        #expect(await manager.advanceToNext()?.trackKey == tracks[0].trackKey)
        #expect(manager.currentIndex == 0)
    }

    @Test func rewindToPreviousRepeatAllWrapsAroundToEnd() {
        let manager = self.makeManager()
        let tracks = [self.track("a"), self.track("b"), self.track("c")]
        manager.setQueue(tracks, startingAt: 0, contextId: "ctx")
        manager.cycleRepeatMode()

        #expect(manager.rewindToPrevious()?.trackKey == tracks[2].trackKey)
        #expect(manager.currentIndex == 2)
    }

    @Test func advanceToNextRepeatAllAllDisabledReturnsNilWithoutInfiniteLoop() async {
        let manager = self.makeManager(disabledSources: [Self.disabledSource])
        let tracks = (0 ..< 3).map { self.track("t\($0)", source: Self.disabledSource) }
        manager.setQueue(tracks, startingAt: 0, contextId: "ctx")
        manager.cycleRepeatMode()

        #expect(await manager.advanceToNext() == nil)
        #expect(manager.currentIndex == 0)
    }

    // MARK: - repeat one

    @Test func advanceToNextRepeatOneReturnsSameTrackWithoutAdvancing() async {
        let manager = self.makeManager()
        let tracks = [self.track("a"), self.track("b"), self.track("c")]
        manager.setQueue(tracks, startingAt: 1, contextId: "ctx")
        manager.cycleRepeatMode()
        manager.cycleRepeatMode()

        #expect(await manager.advanceToNext()?.trackKey == tracks[1].trackKey)
        #expect(manager.currentIndex == 1)
        #expect(await manager.advanceToNext()?.trackKey == tracks[1].trackKey)
        #expect(manager.currentIndex == 1)
    }

    @Test func exitRepeatOneOnUserSkipAllowsAdvanceToActuallyMoveForward() async {
        let manager = self.makeManager()
        let tracks = [self.track("a"), self.track("b"), self.track("c")]
        manager.setQueue(tracks, startingAt: 0, contextId: "ctx")
        manager.cycleRepeatMode()
        manager.cycleRepeatMode()

        manager.exitRepeatOneOnUserSkip()
        #expect(manager.repeatMode == .all)
        #expect(await manager.advanceToNext()?.trackKey == tracks[1].trackKey)
    }

    // MARK: - Radio + repeat interaction

    @Test func enablingRadioTurnsOffRepeatAll() {
        let manager = self.makeManager()
        let tracks = [self.track("a"), self.track("b"), self.track("c")]
        manager.setQueue(tracks, startingAt: 0, contextId: "ctx")
        manager.cycleRepeatMode()
        #expect(manager.repeatMode == .all)

        manager.setShuffleMode(.radio)
        #expect(manager.repeatMode == .off)
    }

    @Test func cycleRepeatModeWhileRadioActiveSkipsRepeatAll() {
        let manager = self.makeManager()
        let tracks = [self.track("a"), self.track("b"), self.track("c")]
        manager.setQueue(tracks, startingAt: 0, contextId: "ctx")
        manager.setShuffleMode(.radio)

        manager.cycleRepeatMode()
        #expect(manager.repeatMode == .one)
        manager.cycleRepeatMode()
        #expect(manager.repeatMode == .off)
    }

    // MARK: - playNext / addToQueue

    @Test func playNextInsertsRightAfterCurrentTrack() {
        let manager = self.makeManager()
        let a = self.track("a")
        let b = self.track("b")
        let c = self.track("c")
        let x = self.track("x")
        manager.setQueue([a, b, c], startingAt: 0, contextId: "ctx")

        manager.playNext(x)

        #expect(self.entryKeys(manager.entries) == self.keys([a, x, b, c]))
        #expect(manager.entries[1].userAdded == true)
        #expect(manager.currentIndex == 0)
    }

    @Test func playNextMultipleCallsStackInReverseOrderRightAfterCurrent() {
        let manager = self.makeManager()
        let a = self.track("a")
        let b = self.track("b")
        let x = self.track("x")
        let y = self.track("y")
        manager.setQueue([a, b], startingAt: 0, contextId: "ctx")

        manager.playNext(x)
        manager.playNext(y)

        #expect(self.entryKeys(manager.entries) == self.keys([a, y, x, b]))
    }

    @Test func addToQueueFallsBackToAfterCurrentWhenNoUserAddedTracksYet() {
        let manager = self.makeManager()
        let a = self.track("a")
        let b = self.track("b")
        let x = self.track("x")
        manager.setQueue([a, b], startingAt: 0, contextId: "ctx")

        manager.addToQueue(x)

        #expect(self.entryKeys(manager.entries) == self.keys([a, x, b]))
    }

    @Test func addToQueueAppendsAfterLastUserAddedTrack() {
        let manager = self.makeManager()
        let a = self.track("a")
        let b = self.track("b")
        let x = self.track("x")
        let y = self.track("y")
        manager.setQueue([a, b], startingAt: 0, contextId: "ctx")

        manager.addToQueue(x)
        manager.addToQueue(y)

        #expect(self.entryKeys(manager.entries) == self.keys([a, x, y, b]))
    }

    @Test func playNextThenAddToQueueCombinedOrdering() {
        let manager = self.makeManager()
        let a = self.track("a")
        let b = self.track("b")
        let x = self.track("x")
        let y = self.track("y")
        let z = self.track("z")
        manager.setQueue([a, b], startingAt: 0, contextId: "ctx")

        manager.playNext(x)
        manager.addToQueue(y)
        manager.playNext(z)

        #expect(self.entryKeys(manager.entries) == self.keys([a, z, x, y, b]))
    }

    // MARK: - removeFromQueue

    @Test func removeFromQueueBeforeCurrentShiftsIndexDown() {
        let manager = self.makeManager()
        let tracks = [self.track("a"), self.track("b"), self.track("c"), self.track("d")]
        manager.setQueue(tracks, startingAt: 1, contextId: "ctx")

        manager.removeFromQueue(manager.entries[0])

        #expect(self.entryKeys(manager.entries) == self.keys([tracks[1], tracks[2], tracks[3]]))
        #expect(manager.currentIndex == 0)
        #expect(manager.currentTrack?.trackKey == tracks[1].trackKey)
    }

    @Test func removeFromQueueAfterCurrentDoesNotShiftIndex() {
        let manager = self.makeManager()
        let tracks = [self.track("a"), self.track("b"), self.track("c"), self.track("d")]
        manager.setQueue(tracks, startingAt: 1, contextId: "ctx")

        manager.removeFromQueue(manager.entries[3])

        #expect(self.entryKeys(manager.entries) == self.keys([tracks[0], tracks[1], tracks[2]]))
        #expect(manager.currentIndex == 1)
        #expect(manager.currentTrack?.trackKey == tracks[1].trackKey)
    }

    @Test func removeFromQueueIsNoOpForCurrentlyPlayingEntry() {
        let manager = self.makeManager()
        let tracks = [self.track("a"), self.track("b"), self.track("c")]
        manager.setQueue(tracks, startingAt: 1, contextId: "ctx")

        manager.removeFromQueue(manager.entries[1])

        #expect(self.entryKeys(manager.entries) == self.keys(tracks))
        #expect(manager.currentIndex == 1)
    }

    // MARK: - applyReorder

    @Test func applyReorderUpdatesOrderAndPreservesCurrentEntry() {
        let manager = self.makeManager()
        let tracks = [self.track("a"), self.track("b"), self.track("c")]
        manager.setQueue(tracks, startingAt: 1, contextId: "ctx")

        let reordered = [manager.entries[2], manager.entries[0], manager.entries[1]]
        manager.applyReorder(reordered)

        #expect(self.entryKeys(manager.entries) == self.keys([tracks[2], tracks[0], tracks[1]]))
        #expect(manager.currentIndex == 2)
        #expect(manager.currentTrack?.trackKey == tracks[1].trackKey)
    }

    @Test func applyReorderKeepsDisabledTracksAppendedAtEnd() {
        let manager = self.makeManager(disabledSources: [Self.disabledSource])
        let a = self.track("a")
        let b = self.track("b", source: Self.disabledSource)
        let c = self.track("c")
        manager.setQueue([a, b, c], startingAt: 0, contextId: "ctx")

        manager.applyReorder([manager.entries[2], manager.entries[0]])

        #expect(self.entryKeys(manager.entries) == self.keys([c, a, b]))
    }

    // MARK: - Shuffle basics

    @Test func toggleShuffleOnAnchorsCurrentTrackAtFront() {
        let manager = self.makeManager()
        let tracks = [self.track("a"), self.track("b"), self.track("c"), self.track("d")]
        manager.setQueue(tracks, startingAt: 2, contextId: "ctx")

        self.toggleShuffle(manager)

        #expect((manager.shuffleMode == .shuffle) == true)
        #expect(manager.currentIndex == 0)
        #expect(manager.activeEntries.first?.track.trackKey == tracks[2].trackKey)
        #expect(manager.currentTrack?.trackKey == tracks[2].trackKey)
    }

    @Test func toggleShuffleOnPlacesUserAddedTracksBeforeShuffledRest() {
        let manager = self.makeManager()
        let a = self.track("a")
        let b = self.track("b")
        let c = self.track("c")
        let x = self.track("x")
        manager.setQueue([a, b, c], startingAt: 0, contextId: "ctx")
        manager.playNext(x)

        self.toggleShuffle(manager)

        #expect(manager.activeEntries[0].track.trackKey == a.trackKey)
        #expect(manager.activeEntries[1].track.trackKey == x.trackKey)
        let remainder = Set(manager.activeEntries[2...].map(\.track.trackKey))
        #expect(remainder == Set([b, c].map(\.trackKey)))
    }

    @Test func toggleShuffleOnPreservesFullTrackSetWhenRepeatAll() {
        let manager = self.makeManager()
        let tracks = (0 ..< 5).map { self.track("t\($0)") }
        manager.setQueue(tracks, startingAt: 2, contextId: "ctx")
        manager.cycleRepeatMode()

        self.toggleShuffle(manager)

        #expect(manager.activeEntries.count == 5)
        #expect(Set(manager.activeEntries.map(\.track.trackKey)) == Set(self.keys(tracks)))
    }

    @Test func toggleShuffleOffRestoresCanonicalOrderAndCurrentIndex() {
        let manager = self.makeManager()
        let tracks = [self.track("a"), self.track("b"), self.track("c"), self.track("d")]
        manager.setQueue(tracks, startingAt: 1, contextId: "ctx")

        self.toggleShuffle(manager)
        self.toggleShuffle(manager)

        #expect((manager.shuffleMode == .shuffle) == false)
        #expect(self.entryKeys(manager.entries) == self.keys(tracks))
        #expect(manager.currentIndex == 1)
        #expect(manager.currentTrack?.trackKey == tracks[1].trackKey)
    }

    // MARK: - Shuffle + repeat interaction

    @Test func shuffleWithRepeatOffExcludesAlreadyPlayedTracksFromPool() {
        let manager = self.makeManager()
        let tracks = (0 ..< 5).map { self.track("t\($0)") }
        manager.setQueue(tracks, startingAt: 2, contextId: "ctx")

        self.toggleShuffle(manager)

        #expect(manager.activeEntries.count == 3)
        #expect(!manager.activeEntries.contains { $0.track.trackKey == tracks[0].trackKey })
        #expect(!manager.activeEntries.contains { $0.track.trackKey == tracks[1].trackKey })
    }

    @Test func shuffleWithRepeatAllIncludesAllTracksInPool() {
        let manager = self.makeManager()
        let tracks = (0 ..< 5).map { self.track("t\($0)") }
        manager.setQueue(tracks, startingAt: 2, contextId: "ctx")
        manager.cycleRepeatMode()

        self.toggleShuffle(manager)

        #expect(manager.activeEntries.count == 5)
        #expect(Set(manager.activeEntries.map(\.track.trackKey)) == Set(self.keys(tracks)))
    }

    @Test func changingRepeatModeWhileShuffledOffToAllExpandsPool() {
        let manager = self.makeManager()
        let tracks = (0 ..< 5).map { self.track("t\($0)") }
        manager.setQueue(tracks, startingAt: 2, contextId: "ctx")
        self.toggleShuffle(manager)
        #expect(manager.shuffledEntries.count == 3)

        manager.cycleRepeatMode()

        #expect(manager.shuffledEntries.count == 5)
        #expect(manager.currentIndex == 0)
        #expect(manager.activeEntries.first?.track.trackKey == tracks[2].trackKey)
    }

    @Test func changingRepeatModeWhileShuffledAllToOffShrinksPool() {
        let manager = self.makeManager()
        let tracks = (0 ..< 5).map { self.track("t\($0)") }
        manager.setQueue(tracks, startingAt: 2, contextId: "ctx")
        manager.cycleRepeatMode()
        self.toggleShuffle(manager)
        #expect(manager.shuffledEntries.count == 5)

        manager.cycleRepeatMode()
        #expect(manager.shuffledEntries.count == 5)
        manager.cycleRepeatMode()
        #expect(manager.shuffledEntries.count == 3)
    }

    // MARK: - Shuffle + mutation interplay

    @Test func addToQueueWhileShuffledUpdatesBothEntriesAndShuffledEntries() {
        let manager = self.makeManager()
        let tracks = [self.track("a"), self.track("b"), self.track("c")]
        let x = self.track("x")
        manager.setQueue(tracks, startingAt: 0, contextId: "ctx")
        self.toggleShuffle(manager)

        manager.addToQueue(x)

        #expect(manager.entries.count == 4)
        #expect(manager.entries.contains { $0.track.trackKey == x.trackKey })
        #expect(manager.shuffledEntries.count == 4)
        #expect(manager.shuffledEntries.contains { $0.track.trackKey == x.trackKey })
    }

    @Test func playNextWhileShuffledInsertsRightAfterAnchorInBothArrays() {
        let manager = self.makeManager()
        let tracks = [self.track("a"), self.track("b"), self.track("c")]
        let x = self.track("x")
        manager.setQueue(tracks, startingAt: 0, contextId: "ctx")
        self.toggleShuffle(manager)

        manager.playNext(x)

        #expect(manager.shuffledEntries[1].track.trackKey == x.trackKey)
        #expect(manager.entries[1].track.trackKey == x.trackKey)
    }

    @Test func removeFromQueueWhileShuffledUpdatesBothEntriesAndShuffledEntries() throws {
        let manager = self.makeManager()
        let tracks = [self.track("a"), self.track("b"), self.track("c"), self.track("d")]
        manager.setQueue(tracks, startingAt: 0, contextId: "ctx")
        self.toggleShuffle(manager)

        let bEntry = try #require(manager.entries.first { $0.track.trackKey == tracks[1].trackKey })
        manager.removeFromQueue(bEntry)

        #expect(!manager.entries.contains { $0.id == bEntry.id })
        #expect(!manager.shuffledEntries.contains { $0.id == bEntry.id })
    }

    // MARK: - Shuffle + reorder interplay

    @Test func reorderWhileShuffledOnlyMutatesShuffledEntriesNotCanonical() {
        let manager = self.makeManager()
        let tracks = [self.track("a"), self.track("b"), self.track("c"), self.track("d")]
        manager.setQueue(tracks, startingAt: 0, contextId: "ctx")
        self.toggleShuffle(manager)

        let original = manager.shuffledEntries
        let swapped = [original[0], original[2], original[1], original[3]]
        manager.applyReorder(swapped)

        #expect(manager.shuffledEntries.map(\.id) == swapped.map(\.id))
        #expect(self.entryKeys(manager.entries) == self.keys(tracks))
    }

    @Test func reorderWhileNotShuffledOnlyMutatesCanonicalEntries() {
        let manager = self.makeManager()
        let tracks = [self.track("a"), self.track("b"), self.track("c")]
        manager.setQueue(tracks, startingAt: 0, contextId: "ctx")

        manager.applyReorder([manager.entries[2], manager.entries[0], manager.entries[1]])

        #expect(self.entryKeys(manager.entries) == self.keys([tracks[2], tracks[0], tracks[1]]))
        #expect(manager.shuffledEntries.isEmpty)
    }

    @Test func reorderWhileShuffledThenToggleCycleDiscardsManualReorder() {
        let manager = self.makeManager()
        let tracks = (0 ..< 5).map { self.track("t\($0)") }
        manager.setQueue(tracks, startingAt: 0, contextId: "ctx")
        self.toggleShuffle(manager)

        let original = manager.shuffledEntries
        let swapped = [original[0], original[2], original[1], original[3], original[4]]
        manager.applyReorder(swapped)

        self.toggleShuffle(manager)
        #expect(self.entryKeys(manager.entries) == self.keys(tracks))
        self.toggleShuffle(manager)
        #expect(manager.shuffledEntries.first?.track.trackKey == tracks[0].trackKey)
        #expect(Set(manager.shuffledEntries.map(\.track.trackKey)) == Set(self.keys(tracks)))
    }

    // MARK: - Combined user paths

    @Test func complexPathReorderThenAddToQueueThenPlayNext() {
        let manager = self.makeManager()
        let tracks = [self.track("a"), self.track("b"), self.track("c"), self.track("d")]
        manager.setQueue(tracks, startingAt: 0, contextId: "ctx")

        manager.applyReorder([manager.entries[0], manager.entries[3], manager.entries[1], manager.entries[2]])
        #expect(self.entryKeys(manager.entries) == self.keys([tracks[0], tracks[3], tracks[1], tracks[2]]))
        let x = self.track("x")
        manager.addToQueue(x)
        #expect(self.entryKeys(manager.entries) == self.keys([tracks[0], x, tracks[3], tracks[1], tracks[2]]))
        let y = self.track("y")
        manager.playNext(y)
        #expect(self.entryKeys(manager.entries) == self.keys([tracks[0], y, x, tracks[3], tracks[1], tracks[2]]))
    }

    @Test func complexPathShuffleToggledMultipleTimesWithMutationsBetween() {
        let manager = self.makeManager()
        let tracks = [self.track("a"), self.track("b"), self.track("c")]
        manager.setQueue(tracks, startingAt: 0, contextId: "ctx")
        let x = self.track("x")
        let y = self.track("y")

        self.toggleShuffle(manager)
        manager.addToQueue(x)
        self.toggleShuffle(manager)
        #expect(Set(self.entryKeys(manager.entries)) == Set(self.keys(tracks) + [x.trackKey]))
        self.toggleShuffle(manager)
        manager.playNext(y)
        #expect(manager.shuffledEntries.count == 5)
        #expect(manager.entries.count == 5)
        self.toggleShuffle(manager)
        let allKeys = self.entryKeys(manager.entries)
        #expect(allKeys.count == 5)
        #expect(Set(allKeys).count == 5)
        #expect(manager.currentTrack?.trackKey == tracks[0].trackKey)
    }
}
