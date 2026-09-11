import SwiftUI

/// The one fade depth used at every scroll edge in the app. Anything that draws its own edge fade
/// should use this too, so the top and bottom of a list always fade by the same amount.
enum EdgeFade {
    static let height: CGFloat = 14
}

/// A small, permanently-visible fade at the top and/or bottom edge of scrollable content.
struct EdgeFadeView<Content: View>: View {
    let content: Content
    let fadeHeight: CGFloat
    let topFadeHeight: CGFloat
    let topInset: CGFloat
    let bottomInset: CGFloat

    @Environment(\.scrollFadeBottomOpaque) private var bottomInsetIsOpaque

    init(
        fadeHeight: CGFloat = EdgeFade.height,
        topFadeHeight: CGFloat = EdgeFade.height,
        topInset: CGFloat = 0,
        bottomInset: CGFloat = 0,
        @ViewBuilder content: () -> Content
    ) {
        self.fadeHeight = fadeHeight
        self.topFadeHeight = topFadeHeight
        self.topInset = topInset
        self.bottomInset = bottomInset
        self.content = content()
    }

    var body: some View {
        self.content
            .overlay(alignment: .top) {
                VStack(spacing: 0) {
                    Color.black
                        .frame(height: self.topInset)
                    LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: self.topFadeHeight)
                }
                .allowsHitTesting(false)
            }
            .overlay(alignment: .bottom) {
                VStack(spacing: 0) {
                    LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                        .frame(height: self.fadeHeight)
                    (self.bottomInsetIsOpaque ? Color.black : Color.clear)
                        .frame(height: self.bottomInset)
                }
                .ignoresSafeArea(edges: .bottom)
                .allowsHitTesting(false)
            }
    }
}
