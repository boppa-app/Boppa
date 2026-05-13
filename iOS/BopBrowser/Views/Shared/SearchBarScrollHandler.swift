import SwiftUI
import UIKit

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

    let searchBarHeight: CGFloat = 46
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

        // Scrolling down - use distance-based detection
        if delta > 0 {
            self.accumulatedScrollDown += delta
            self.accumulatedScrollUp = 0 // Reset scroll up accumulator

            // Hide when accumulated scroll down exceeds threshold
            if self.accumulatedScrollDown > scrollDownThreshold {
                if self.showSearchBar {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.showSearchBar = false
                    }
                    self.accumulatedScrollDown = 0
                }
            }
        }
        // Scrolling up - use velocity + distance-based detection
        else if delta < 0 {
            self.accumulatedScrollDown = 0 // Reset scroll down accumulator

            // Accumulate if velocity is high enough OR if the spacer is about to become visible (contentOffset < searchBarHeight).
            // This ensures the search bar always appears before the black spacer is exposed, even during very slow scrolls.
            let spacerAboutToShow = newInfo.contentOffset < self.searchBarHeight
            if velocity > velocityThreshold || spacerAboutToShow {
                self.accumulatedScrollUp += abs(delta)

                // Show when both velocity and distance thresholds are met
                if self.accumulatedScrollUp > scrollUpThreshold || spacerAboutToShow, !self.showSearchBar {
                    // Dynamically calculate animation duration based on how quickly the scroll will reach the top.
                    // This ensures the search bar finishes appearing before the spacer is fully exposed.
                    let maxFPS = CGFloat(UIScreen.main.maximumFramesPerSecond)
                    let framesUntilTop = velocity > 0 ? newInfo.contentOffset / velocity : 0
                    let secondsUntilTop = framesUntilTop / maxFPS
                    let duration = min(2 * secondsUntilTop, 0.3)

                    withAnimation(.easeInOut(duration: duration)) {
                        self.showSearchBar = true
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
