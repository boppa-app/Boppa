import SwiftUI

struct DetailHeaderOverlayButton: View {
    let systemImage: String
    let accessibilityLabel: String
    let accessibilityHint: String
    let scrollHandler: ScrollAwareVisibilityHandler
    let isNavigatingAway: Bool
    let action: () -> Void

    static let diameter: CGFloat = 44

    private var isVisible: Bool {
        self.scrollHandler.isHeaderVisible && !self.isNavigatingAway
    }

    var body: some View {
        Button(action: self.action) {
            Image(systemName: self.systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: Self.diameter, height: Self.diameter)
                .background(Circle().fill(Color.purp))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(self.accessibilityLabel)
        .accessibilityHint(self.accessibilityHint)
        .accessibilityAddTraits(.isButton)
        .opacity(self.isVisible ? 1 : 0)
        .scaleEffect(self.isVisible ? 1 : 0.6)
        .animation(.easeInOut(duration: 0.1), value: self.isNavigatingAway)
        .animation(.easeInOut(duration: 0.2), value: self.scrollHandler.isHeaderVisible)
        .allowsHitTesting(self.isVisible)
        .padding(.top, DetailHeaderMetrics.height - Self.diameter / 2)
        .padding(.trailing, 44)
    }
}
