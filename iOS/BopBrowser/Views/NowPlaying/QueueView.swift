import SwiftUI

struct QueueView: View {
    private var playbackService: PlaybackService {
        PlaybackService.shared
    }

    private var queueManager: SongQueueManager {
        SongQueueManager.shared
    }

    var body: some View {
        let displayQueue = self.queueManager.displayQueue
        let repeatMode = self.queueManager.repeatMode
        let lastIndex = displayQueue.count - 1

        ScrollFadeView {
            List {
                ForEach(Array(displayQueue.enumerated()), id: \.element.id) { index, song in
                    let isCurrent = song == self.queueManager.currentTrack
                    Button {
                        if repeatMode != .one {
                            if let source = self.playbackService.mediaSource {
                                self.playbackService.playTrack(song, queue: self.queueManager.queue, mediaSource: source)
                            }
                        }
                    } label: {
                        SongRow(
                            song: song,
                            isSelected: isCurrent,
                            isLoading: self.playbackService.isLoading,
                            isPlaying: self.playbackService.isPlaying && isCurrent,
                            style: .compact
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.black)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowSeparatorTint(index == lastIndex ? .clear : Color(.systemGray6))
                }
                .onMove { source, destination in
                    var reordered = self.queueManager.displayQueue
                    reordered.move(fromOffsets: source, toOffset: destination)
                    withAnimation(nil) {
                        self.queueManager.applyReorderedDisplayQueue(reordered)
                    }
                }
            }
            .listStyle(.plain)
            .environment(\.editMode, .constant(repeatMode == .one ? .inactive : .active))
            .scrollIndicators(.hidden)
            .scrollContentBackground(.hidden)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.black)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
    }
}
