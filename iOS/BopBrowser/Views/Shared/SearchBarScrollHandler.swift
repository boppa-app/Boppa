import SwiftUI

struct ScrollInfo: Equatable {
    var contentOffset: CGFloat
    var contentHeight: CGFloat
    var containerHeight: CGFloat
}

struct ScrollDirectionTracker: ViewModifier {
    let isEnabled: Bool
    let onScrollChange: (_ oldInfo: ScrollInfo, _ newInfo: ScrollInfo) -> Void

    func body(content: Content) -> some View {
        if self.isEnabled {
            if #available(iOS 18.0, *) {
                content
                    .onScrollGeometryChange(for: ScrollInfo.self) { geometry in
                        ScrollInfo(
                            contentOffset: geometry.contentOffset.y,
                            contentHeight: geometry.contentSize.height,
                            containerHeight: geometry.visibleRect.height
                        )
                    } action: { oldInfo, newInfo in
                        self.onScrollChange(oldInfo, newInfo)
                    }
            } else {
                content
            }
        } else {
            content
        }
    }
}

@MainActor
@Observable
class SearchBarScrollHandler {
    var showSearchBar = true
    var searchBarTopFade: CGFloat = 0

    let searchBarHeight: CGFloat = 52
    let fadeHeight: CGFloat = 40

    private var accumulatedScrollDelta: CGFloat = 0

    func handleScrollChange(oldInfo: ScrollInfo, newInfo: ScrollInfo, isSearchFieldFocused: Bool) {
        // Update fade based on scroll offset
        self.searchBarTopFade = min(max(newInfo.contentOffset, 0) / self.fadeHeight, 1)

        let isScrollable = newInfo.contentHeight > newInfo.containerHeight + 50
        guard isScrollable, !isSearchFieldFocused else { return }

        let delta = newInfo.contentOffset - oldInfo.contentOffset
        let scrollThreshold: CGFloat = 50

        // Always show when at or near the top
        if newInfo.contentOffset <= 0 {
            self.accumulatedScrollDelta = 0
            if !self.showSearchBar {
                withAnimation(.easeInOut(duration: 0.4)) {
                    self.showSearchBar = true
                }
            }
            return
        }

        // Accumulate delta in the same direction, reset if direction changes
        if (delta > 0 && self.accumulatedScrollDelta < 0) || (delta < 0 && self.accumulatedScrollDelta > 0) {
            self.accumulatedScrollDelta = 0
        }

        self.accumulatedScrollDelta += delta

        // Hide on accumulated scroll down exceeds threshold
        if self.accumulatedScrollDelta > scrollThreshold {
            if self.showSearchBar {
                withAnimation(.easeInOut(duration: 0.4)) {
                    self.showSearchBar = false
                }
                self.accumulatedScrollDelta = 0
            }
        }
        // Show on accumulated scroll up exceeds threshold
        else if self.accumulatedScrollDelta < -scrollThreshold {
            if !self.showSearchBar {
                // When near the top, show immediately without animation so the
                // search bar is fully visible before the black spacer is exposed
                let velocity = abs(delta)
                let framesUntilTop = velocity > 0 ? newInfo.contentOffset / velocity : .infinity
                let animationFrames: CGFloat = 48 // ~0.4s at 120fps
                if framesUntilTop < animationFrames {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        self.showSearchBar = true
                    }
                } else {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        self.showSearchBar = true
                    }
                }
                self.accumulatedScrollDelta = 0
            }
        }
    }
}
