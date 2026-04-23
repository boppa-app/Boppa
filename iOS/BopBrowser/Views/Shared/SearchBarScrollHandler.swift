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

    private var accumulatedScrollDown: CGFloat = 0
    private var accumulatedScrollUp: CGFloat = 0

    func handleScrollChange(oldInfo: ScrollInfo, newInfo: ScrollInfo, isSearchFieldFocused: Bool) {
        // Update fade based on scroll offset
        self.searchBarTopFade = min(max(newInfo.contentOffset, 0) / self.fadeHeight, 1)

        let isScrollable = newInfo.contentHeight > newInfo.containerHeight + 50
        guard isScrollable, !isSearchFieldFocused else { return }

        let delta = newInfo.contentOffset - oldInfo.contentOffset
        let velocity = abs(delta)
        let velocityThreshold: CGFloat = 30.0 // Minimum velocity to trigger show on scroll up
        let scrollDownThreshold: CGFloat = 300 // Distance threshold for hiding on scroll down
        let scrollUpThreshold: CGFloat = 100 // Distance threshold for showing on scroll up

        // Always show when at or near the top
        if newInfo.contentOffset <= 0 {
            self.accumulatedScrollDown = 0
            self.accumulatedScrollUp = 0
            if !self.showSearchBar {
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.showSearchBar = true
                }
            }
            return
        }

        // Scrolling down - use distance-based detection
        if delta > 0 {
            self.accumulatedScrollDown += delta
            self.accumulatedScrollUp = 0 // Reset scroll up accumulator
            
            // Hide when accumulated scroll down exceeds threshold
            if self.accumulatedScrollDown > scrollDownThreshold {
                if self.showSearchBar {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.showSearchBar = false
                    }
                    self.accumulatedScrollDown = 0
                }
            }
        }
        // Scrolling up - use velocity + distance-based detection
        else if delta < 0 {
            self.accumulatedScrollDown = 0 // Reset scroll down accumulator
            
            // Only accumulate if velocity is high enough
            if velocity > velocityThreshold {
                self.accumulatedScrollUp += abs(delta)
                
                // Show when both velocity and distance thresholds are met
                if self.accumulatedScrollUp > scrollUpThreshold && !self.showSearchBar {
                    // When near the top, show immediately without animation so the
                    // search bar is fully visible before the black spacer is exposed
                    let framesUntilTop = velocity > 0 ? newInfo.contentOffset / velocity : .infinity
                    let animationFrames: CGFloat = 48 // ~0.4s at 120fps
                    if framesUntilTop < animationFrames {
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            self.showSearchBar = true
                        }
                    } else {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            self.showSearchBar = true
                        }
                    }
                    self.accumulatedScrollUp = 0
                }
            } else {
                // Reset if velocity drops below threshold
                self.accumulatedScrollUp = 0
            }
        }
    }
}
