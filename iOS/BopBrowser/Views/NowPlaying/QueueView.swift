import SwiftUI

private struct ScrollGeometryInfo: Equatable {
    var contentOffset: CGFloat
    var contentHeight: CGFloat
    var containerHeight: CGFloat
}

private struct ScrollFadeModifier: ViewModifier {
    @Binding var topFade: CGFloat
    @Binding var bottomFade: CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content
                .onScrollGeometryChange(for: ScrollGeometryInfo.self) { geometry in
                    ScrollGeometryInfo(
                        contentOffset: geometry.contentOffset.y,
                        contentHeight: geometry.contentSize.height,
                        containerHeight: geometry.visibleRect.height
                    )
                } action: { _, newValue in
                    let fadeThreshold: CGFloat = 40
                    self.topFade = min(newValue.contentOffset / fadeThreshold, 1)
                    let bottomOffset = newValue.contentHeight - newValue.containerHeight - newValue.contentOffset
                    self.bottomFade = min(max(bottomOffset, 0) / fadeThreshold, 1)
                }
        } else {
            content
        }
    }
}

struct QueueView: View {
    private var playbackService: PlaybackService {
        PlaybackService.shared
    }

    private var queueManager: SongQueueManager {
        SongQueueManager.shared
    }

    @State private var topFade: CGFloat = 0
    @State private var bottomFade: CGFloat = 1

    var body: some View {
        let displayQueue = self.queueManager.displayQueue
        let repeatMode = self.queueManager.repeatMode
        let lastIndex = displayQueue.count - 1

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
        .modifier(ScrollFadeModifier(topFade: self.$topFade, bottomFade: self.$bottomFade))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .mask(
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [.black.opacity(1 - self.topFade), .black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 40)

                Color.black

                LinearGradient(
                    colors: [.black, .black.opacity(1 - self.bottomFade)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 40)
            }
        )
        .background(Color.black)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
    }
}
