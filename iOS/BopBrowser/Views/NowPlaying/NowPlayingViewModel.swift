import Foundation
import SwiftUI

@Observable
@MainActor
final class NowPlayingViewModel {
    var onOpenInBrowser: ((String) -> Void)?

    var isSeeking = false
    var seekValue: Double = 0
    var showQueue = false

    private var playbackService: PlaybackService {
        PlaybackService.shared
    }

    private var queueManager: SongQueueManager {
        SongQueueManager.shared
    }

    var currentTrack: Song? {
        self.playbackService.currentTrack
    }

    var isPlaying: Bool {
        self.playbackService.isPlaying
    }

    var isLoading: Bool {
        self.playbackService.isLoading
    }

    var currentTime: Double {
        self.playbackService.currentTime
    }

    var duration: Double {
        self.playbackService.duration
    }

    var queue: [Song] {
        self.queueManager.queue
    }

    var repeatMode: RepeatMode {
        self.queueManager.repeatMode
    }

    var artworkURL: URL? {
        guard let artworkUrl = self.currentTrack?.artworkUrl else { return nil }
        return URL(string: artworkUrl)
    }

    var trackTitle: String {
        self.currentTrack?.title ?? "Not Playing"
    }

    var trackArtist: String {
        self.currentTrack?.artist ?? ""
    }

    var songUrl: String? {
        self.currentTrack?.url
    }

    var hasSongUrl: Bool {
        self.songUrl != nil
    }

    var displayCurrentTime: Double {
        self.isSeeking ? self.seekValue : self.currentTime
    }

    var seekMaximum: Double {
        max(self.duration, 1)
    }

    var formattedCurrentTime: String {
        Song.formatTime(seconds: self.displayCurrentTime)
    }

    var formattedDuration: String {
        Song.formatTime(seconds: self.duration)
    }

    var playPauseIconName: String {
        self.isPlaying ? "pause.fill" : "play.fill"
    }

    var repeatIconName: String {
        switch self.repeatMode {
        case .off, .all:
            return "repeat"
        case .one:
            return "repeat.1"
        }
    }

    var isRepeatActive: Bool {
        self.repeatMode != .off
    }

    var canGoBack: Bool {
        !self.queue.isEmpty
    }

    var canSkipForward: Bool {
        self.queue.count > 1
    }

    func togglePlayPause() {
        self.playbackService.togglePlayPause()
    }

    func previous() {
        self.playbackService.previous()
    }

    func next() {
        self.playbackService.next()
    }

    func seek(to time: Double) {
        self.playbackService.seek(to: time)
    }

    func cycleRepeatMode() {
        self.queueManager.cycleRepeatMode()
    }

    func handleSeekEditingChanged(editing: Bool, newValue: Double) {
        if editing {
            self.isSeeking = true
            self.seekValue = newValue
        } else {
            self.seek(to: newValue)
            self.isSeeking = false
        }
    }

    func handleSeekValueChanged(newValue: Double) {
        self.seekValue = newValue
    }

    func toggleQueue() {
        withAnimation(.easeInOut(duration: 0.25)) {
            self.showQueue.toggle()
        }
    }

    func openInBrowser(dismiss: DismissAction) {
        guard let url = self.songUrl else { return }
        dismiss()
        self.onOpenInBrowser?(url)
    }
}
