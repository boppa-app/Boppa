import SwiftUI

struct HorizontalFadeModifier: ViewModifier {
    @Binding var leftFade: CGFloat
    @Binding var rightFade: CGFloat
    let fadeWidth: CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content
                .onScrollGeometryChange(for: CGPoint.self) { geometry in
                    CGPoint(x: geometry.contentOffset.x, y: geometry.contentSize.width - geometry.visibleRect.width)
                } action: { _, new in
                    let offsetX = new.x
                    let overflow = new.y
                    self.leftFade = min(offsetX / self.fadeWidth, 1)
                    self.rightFade = overflow > 0 ? min(max(overflow - offsetX, 0) / self.fadeWidth, 1) : 0
                }
        } else {
            content
        }
    }
}

/// Fade effect is only available on iOS 18.0+
struct HorizontalScrollFadeView<Content: View>: View {
    let content: Content
    let fadeWidth: CGFloat

    @State private var leftFade: CGFloat = 0
    @State private var rightFade: CGFloat = 0

    init(fadeWidth: CGFloat = 40, @ViewBuilder content: () -> Content) {
        self.fadeWidth = fadeWidth
        self.content = content()
    }

    var body: some View {
        self.content
            .modifier(HorizontalFadeModifier(
                leftFade: self.$leftFade,
                rightFade: self.$rightFade,
                fadeWidth: self.fadeWidth
            ))
            .mask(
                HStack(spacing: 0) {
                    LinearGradient(
                        colors: [.black.opacity(1 - self.leftFade), .black],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: self.fadeWidth)

                    Color.black

                    LinearGradient(
                        colors: [.black, .black.opacity(1 - self.rightFade)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: self.fadeWidth)
                }
            )
    }
}
