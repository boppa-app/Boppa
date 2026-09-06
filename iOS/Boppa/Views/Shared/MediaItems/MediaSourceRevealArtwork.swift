import SwiftUI

enum MediaSourceRevealIcon {
    case svg(String)
    case asset(String)
}

struct MediaSourceRevealArtwork<Content: View>: View {
    var size: CGFloat = 48
    var cornerRadius: CGFloat?
    var borderColor: Color? = nil
    var mediaSourceRevealIcon: MediaSourceRevealIcon? = nil
    var revealBackgroundColor: Color = .init(.systemGray5)
    @ViewBuilder var content: () -> Content

    @State private var isRevealingMediaSource = false
    @State private var revealTask: Task<Void, Never>?

    private var resolvedCornerRadius: CGFloat {
        self.cornerRadius ?? 6
    }

    @ViewBuilder
    private func revealGlyph(_ icon: MediaSourceRevealIcon) -> some View {
        switch icon {
        case let .svg(svg):
            SVGImageView(svgString: svg, size: self.size * 0.6)
        case let .asset(name):
            Image(name)
                .resizable()
                .scaledToFit()
                .frame(width: self.size * 0.6, height: self.size * 0.6)
        }
    }

    private func mediaSourceRevealContent(icon: MediaSourceRevealIcon) -> some View {
        RoundedRectangle(cornerRadius: self.resolvedCornerRadius)
            .fill(self.revealBackgroundColor)
            .frame(width: self.size, height: self.size)
            .overlay {
                self.revealGlyph(icon)
            }
            .overlay {
                if let borderColor = self.borderColor {
                    RoundedRectangle(cornerRadius: self.resolvedCornerRadius)
                        .strokeBorder(borderColor, lineWidth: 2)
                }
            }
    }

    private func stackedContent(icon: MediaSourceRevealIcon? = nil) -> some View {
        ZStack {
            self.content()
                .opacity(self.isRevealingMediaSource ? 0 : 1)
            if let icon {
                self.mediaSourceRevealContent(icon: icon)
                    .opacity(self.isRevealingMediaSource ? 1 : 0)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: self.isRevealingMediaSource)
    }

    var body: some View {
        if let mediaSourceRevealIcon = self.mediaSourceRevealIcon {
            self.stackedContent(icon: mediaSourceRevealIcon)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    self.revealMediaSource()
                }
        } else {
            self.stackedContent()
        }
    }

    private func revealMediaSource() {
        self.revealTask?.cancel()
        self.isRevealingMediaSource = true
        self.revealTask = Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            self.isRevealingMediaSource = false
        }
    }
}
