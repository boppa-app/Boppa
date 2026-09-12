import SwiftUI

enum ScrollFadeEdge {
    case top
    case bottom
}

struct EdgeGradientFade: View {
    let edge: ScrollFadeEdge
    let visibility: CGFloat
    var gradientExtension: CGFloat
    var solidExtent: CGFloat = 0

    private var gradient: some View {
        LinearGradient(
            colors: self.edge == .top
                ? [.black.opacity(1), .black.opacity(0)]
                : [.black.opacity(0), .black.opacity(1)],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: self.gradientExtension * self.visibility)
    }

    private var solid: some View {
        Color.black.frame(height: self.solidExtent)
    }

    var body: some View {
        VStack(spacing: 0) {
            if self.edge == .top {
                self.solid
                self.gradient
            } else {
                self.gradient
                self.solid
            }
        }
        .animation(.easeOut(duration: 0.25), value: self.visibility)
        .allowsHitTesting(false)
    }
}

@available(iOS 18.0, *)
extension ScrollFadeEdge {
    func proximity(in geometry: ScrollGeometry, threshold: CGFloat) -> CGFloat {
        let threshold = max(threshold, 1)
        switch self {
        case .top:
            let distance = geometry.contentOffset.y + geometry.contentInsets.top
            return min(max(distance, 0) / threshold, 1)
        case .bottom:
            let distance = geometry.contentSize.height
                + geometry.contentInsets.bottom
                - geometry.visibleRect.maxY
            return min(max(distance, 0) / threshold, 1)
        }
    }
}

private struct ScrollEdgeProximityModifier: ViewModifier {
    let edge: ScrollFadeEdge
    @Binding var visibility: CGFloat
    let fadeThreshold: CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    self.edge.proximity(in: geometry, threshold: self.fadeThreshold)
                } action: { _, newValue in
                    self.visibility = newValue
                }
        } else {
            content
        }
    }
}

extension View {
    func reportsScrollEdgeProximity(
        _ edge: ScrollFadeEdge,
        visibility: Binding<CGFloat>,
        fadeThreshold: CGFloat = 25
    ) -> some View {
        self.modifier(ScrollEdgeProximityModifier(
            edge: edge,
            visibility: visibility,
            fadeThreshold: fadeThreshold
        ))
    }
}
