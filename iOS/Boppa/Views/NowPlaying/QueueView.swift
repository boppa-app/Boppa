import SwiftUI

struct QueueView: View {
    private var playbackService: PlaybackService {
        PlaybackService.shared
    }

    private var queueManager: TrackQueueManager {
        TrackQueueManager.shared
    }

    var body: some View {
        let displayNodes = self.queueManager.displayQueueNodes
        let repeatMode = self.queueManager.repeatMode
        let lastIndex = displayNodes.count - 1

        ScrollFadeView {
            List {
                ForEach(Array(displayNodes.enumerated()), id: \.element.id) { index, node in
                    let isCurrent = node.isSelected
                    TrackRow(
                        track: node.track,
                        isSelected: isCurrent,
                        isLoading: self.playbackService.isLoading,
                        isPlaying: self.playbackService.isPlaying && isCurrent,
                        style: .compact,
                        onTap: {
                            if repeatMode != .one {
                                self.queueManager.jump(to: node)
                                self.playbackService.playTrack(node.track)
                            }
                        },
                        onDeleteTap: node.userAdded ? {
                            self.queueManager.removeFromQueue(node)
                        } : nil,
                        isDeleteDisabled: node.isSelected
                    )
                    .listRowBackground(Color.black)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowSeparatorTint(index == lastIndex ? .clear : Color(.systemGray6))
                }
                .onMove { source, destination in
                    var reordered = self.queueManager.displayQueueNodes
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
            .animation(.default)
        }
        .background(Color.black)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
    }
}
