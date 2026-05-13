import SwiftUI

private struct ScrollGeometryInfo: Equatable {
    var contentOffset: CGFloat
    var contentHeight: CGFloat
    var containerHeight: CGFloat
}

private struct ScrollFadeModifier: ViewModifier {
    @Binding var topFade: CGFloat
    @Binding var bottomFade: CGFloat
    let fadeThreshold: CGFloat

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
                    self.topFade = min(newValue.contentOffset / self.fadeThreshold, 1)
                    let bottomOffset = newValue.contentHeight - newValue.containerHeight - newValue.contentOffset
                    self.bottomFade = min(max(bottomOffset, 0) / self.fadeThreshold, 1)
                }
        } else {
            content
        }
    }
}

/// Fade effect is only available on iOS 18.0+
struct ScrollFadeView<Content: View>: View {
    let content: Content
    let fadeHeight: CGFloat

    @State private var topFade: CGFloat = 0
    @State private var bottomFade: CGFloat = 1

    init(fadeHeight: CGFloat = 40, @ViewBuilder content: () -> Content) {
        self.fadeHeight = fadeHeight
        self.content = content()
    }

    var body: some View {
        self.content
            .modifier(ScrollFadeModifier(
                topFade: self.$topFade,
                bottomFade: self.$bottomFade,
                fadeThreshold: self.fadeHeight
            ))
            .mask(
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [.black.opacity(1 - self.topFade), .black],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: self.fadeHeight)

                    Color.black

                    LinearGradient(
                        colors: [.black, .black.opacity(1 - self.bottomFade)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: self.fadeHeight)
                }
            )
    }
}
