import SwiftUI

struct MarqueeText: View {
    let text: String
    let highlightedPrefix: String?
    let highlightedPrefixColor: Color
    let font: Font
    let fontWeight: Font.Weight
    let foregroundColor: Color
    let speed: Double
    let startPauseDuration: Double
    let endPauseDuration: Double
    let fadeWidth: CGFloat
    let uniqueId: String?
    let visible: Bool
    let visibleResetDelay: Double
    let maxWidth: CGFloat?
    let alignment: Alignment

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var leadingFade: CGFloat = 0
    @State private var trailingFade: CGFloat = 1
    @State private var animationTask: Task<Void, Never>?
    @State private var viewID: UUID = .init()

    private var overflows: Bool {
        if let maxW = self.maxWidth {
            return self.textWidth > maxW && maxW > 0
        } else {
            return self.textWidth > self.containerWidth && self.containerWidth > 0
        }
    }

    private var overflowAmount: CGFloat {
        max(self.textWidth - self.containerWidth, 0)
    }

    init(
        _ text: String,
        highlightedPrefix: String? = nil,
        highlightedPrefixColor: Color = .purp,
        font: Font = .body,
        fontWeight: Font.Weight = .regular,
        foregroundColor: Color = .white,
        speed: Double = 30,
        startPauseDuration: Double = 2.5,
        endPauseDuration: Double = 2.5,
        fadeWidth: CGFloat = 16,
        uniqueId: String? = nil,
        visible: Bool = true,
        visibleResetDelay: Double = 0.5,
        maxWidth: CGFloat? = nil,
        alignment: Alignment = .leading
    ) {
        self.text = text
        self.highlightedPrefix = highlightedPrefix
        self.highlightedPrefixColor = highlightedPrefixColor
        self.font = font
        self.fontWeight = fontWeight
        self.foregroundColor = foregroundColor
        self.speed = speed
        self.startPauseDuration = startPauseDuration
        self.endPauseDuration = endPauseDuration
        self.fadeWidth = fadeWidth
        self.uniqueId = uniqueId
        self.visible = visible
        self.visibleResetDelay = visibleResetDelay
        self.maxWidth = maxWidth
        self.alignment = alignment
    }

    var body: some View {
        let effectiveWidth = self.maxWidth.map { min($0, self.measureTextWidth()) } ?? nil

        GeometryReader { geometry in
            let containerW = geometry.size.width
            ZStack(alignment: self.overflows ? .leading : self.alignment) {
                if self.overflows {
                    self.scrollingContent
                } else {
                    self.staticContent
                }
            }
            .frame(width: containerW, alignment: self.overflows ? .leading : self.alignment)
            .clipped()
            .mask {
                if self.overflows {
                    self.fadeMask(width: containerW)
                } else {
                    Rectangle()
                }
            }
            .id(self.viewID)
            .onAppear {
                self.containerWidth = containerW
            }
            .onChange(of: containerW) { _, newValue in
                self.containerWidth = newValue
                self.restartAnimation()
            }
            .onChange(of: self.uniqueId) { _, _ in
                self.restartAnimation()
            }
            .onChange(of: self.visible) { _, newValue in
                if newValue {
                    self.restartAnimation(delay: self.visibleResetDelay)
                }
            }
        }
        .frame(width: effectiveWidth, height: self.measureTextHeight())
    }

    private var staticContent: some View {
        self.styledText
            .background(
                GeometryReader { textGeometry in
                    Color.clear
                        .onAppear {
                            self.textWidth = textGeometry.size.width
                        }
                        .onChange(of: self.text) { _, _ in
                            self.textWidth = textGeometry.size.width
                        }
                }
            )
    }

    private var scrollingContent: some View {
        self.styledText
            .offset(x: self.scrollOffset)
            .background(
                self.styledText
                    .background(
                        GeometryReader { textGeometry in
                            Color.clear
                                .onAppear {
                                    self.textWidth = textGeometry.size.width
                                }
                                .onChange(of: self.text) { _, _ in
                                    self.textWidth = textGeometry.size.width
                                }
                        }
                    )
                    .hidden()
            )
            .onAppear {
                self.startAnimationLoop()
            }
            .onDisappear {
                self.animationTask?.cancel()
                self.animationTask = nil
            }
    }

    private var styledText: some View {
        Group {
            if let prefix = self.highlightedPrefix {
                (
                    Text(prefix)
                        .font(self.font)
                        .fontWeight(self.fontWeight)
                        .foregroundColor(.white)
                        + Text("  |  ")
                        .font(self.font)
                        .fontWeight(self.fontWeight)
                        .foregroundColor(Color(.systemGray3))
                        + Text(self.text)
                        .font(self.font)
                        .fontWeight(self.fontWeight)
                        .foregroundColor(Color(.systemGray))
                )
                .fixedSize()
                .lineLimit(1)
            } else {
                Text(self.text)
                    .font(self.font)
                    .fontWeight(self.fontWeight)
                    .foregroundColor(self.foregroundColor)
                    .fixedSize()
                    .lineLimit(1)
            }
        }
    }

    private var fullDisplayText: String {
        if let prefix = self.highlightedPrefix {
            return "\(prefix) — \(self.text)"
        }
        return self.text
    }

    private func fadeMask(width: CGFloat) -> some View {
        HStack(spacing: 0) {
            LinearGradient(
                colors: [.black.opacity(1 - self.leadingFade), .black],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: self.fadeWidth)

            Color.black

            LinearGradient(
                colors: [.black, .black.opacity(1 - self.trailingFade)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: self.fadeWidth)
        }
        .frame(width: width)
    }

    private func startAnimationLoop() {
        self.animationTask?.cancel()
        self.phaseStartPause()
    }

    private func phaseStartPause() {
        self.scrollOffset = 0
        self.leadingFade = 0
        self.trailingFade = 1

        self.animationTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(self.startPauseDuration))
            guard !Task.isCancelled, self.overflows else { return }
            self.phaseScrollLeft()
        }
    }

    private func phaseScrollLeft() {
        let distance = self.overflowAmount
        let duration = distance / self.speed

        withAnimation(.easeIn(duration: min(0.3, duration * 0.3))) {
            self.leadingFade = 1
        }
        withAnimation(.easeOut(duration: min(0.3, duration * 0.3)).delay(max(duration - 0.3, 0))) {
            self.trailingFade = 0
        }

        withAnimation(.linear(duration: duration)) {
            self.scrollOffset = -distance
        }

        self.animationTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            self.phaseEndPause()
        }
    }

    private func phaseEndPause() {
        self.animationTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(self.endPauseDuration))
            guard !Task.isCancelled, self.overflows else { return }
            self.phaseScrollRight()
        }
    }

    private func phaseScrollRight() {
        let distance = self.overflowAmount
        let duration = distance / self.speed

        withAnimation(.easeOut(duration: min(0.3, duration * 0.3)).delay(max(duration - 0.3, 0))) {
            self.leadingFade = 0
        }
        withAnimation(.easeIn(duration: min(0.3, duration * 0.3))) {
            self.trailingFade = 1
        }

        withAnimation(.linear(duration: duration)) {
            self.scrollOffset = 0
        }

        self.animationTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            self.phaseStartPause()
        }
    }

    private func restartAnimation(delay: Double = 0) {
        self.animationTask?.cancel()
        self.animationTask = nil

        self.scrollOffset = 0
        self.leadingFade = 0
        self.trailingFade = 1

        self.viewID = UUID()

        DispatchQueue.main.asyncAfter(deadline: .now() + max(delay, 0.1)) {
            if self.overflows {
                self.startAnimationLoop()
            }
        }
    }

    private func measureTextHeight() -> CGFloat {
        let uiFont: UIFont
        switch self.font {
        case .largeTitle:
            uiFont = UIFont.preferredFont(forTextStyle: .largeTitle)
        case .title:
            uiFont = UIFont.preferredFont(forTextStyle: .title1)
        case .title2:
            uiFont = UIFont.preferredFont(forTextStyle: .title2)
        case .title3:
            uiFont = UIFont.preferredFont(forTextStyle: .title3)
        case .headline:
            uiFont = UIFont.preferredFont(forTextStyle: .headline)
        case .subheadline:
            uiFont = UIFont.preferredFont(forTextStyle: .subheadline)
        case .body:
            uiFont = UIFont.preferredFont(forTextStyle: .body)
        case .callout:
            uiFont = UIFont.preferredFont(forTextStyle: .callout)
        case .footnote:
            uiFont = UIFont.preferredFont(forTextStyle: .footnote)
        case .caption:
            uiFont = UIFont.preferredFont(forTextStyle: .caption1)
        case .caption2:
            uiFont = UIFont.preferredFont(forTextStyle: .caption2)
        default:
            uiFont = UIFont.preferredFont(forTextStyle: .body)
        }
        return uiFont.lineHeight
    }

    private func measureTextWidth() -> CGFloat {
        let uiFont: UIFont
        switch self.font {
        case .largeTitle:
            uiFont = UIFont.preferredFont(forTextStyle: .largeTitle)
        case .title:
            uiFont = UIFont.preferredFont(forTextStyle: .title1)
        case .title2:
            uiFont = UIFont.preferredFont(forTextStyle: .title2)
        case .title3:
            uiFont = UIFont.preferredFont(forTextStyle: .title3)
        case .headline:
            uiFont = UIFont.preferredFont(forTextStyle: .headline)
        case .subheadline:
            uiFont = UIFont.preferredFont(forTextStyle: .subheadline)
        case .body:
            uiFont = UIFont.preferredFont(forTextStyle: .body)
        case .callout:
            uiFont = UIFont.preferredFont(forTextStyle: .callout)
        case .footnote:
            uiFont = UIFont.preferredFont(forTextStyle: .footnote)
        case .caption:
            uiFont = UIFont.preferredFont(forTextStyle: .caption1)
        case .caption2:
            uiFont = UIFont.preferredFont(forTextStyle: .caption2)
        default:
            uiFont = UIFont.preferredFont(forTextStyle: .body)
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: uiFont.withWeight(self.fontWeight),
        ]
        let size = (self.fullDisplayText as NSString).size(withAttributes: attributes)
        return size.width
    }
}

extension UIFont {
    func withWeight(_ weight: Font.Weight) -> UIFont {
        let traits: [UIFontDescriptor.TraitKey: Any]
        switch weight {
        case .ultraLight:
            traits = [.weight: UIFont.Weight.ultraLight]
        case .thin:
            traits = [.weight: UIFont.Weight.thin]
        case .light:
            traits = [.weight: UIFont.Weight.light]
        case .regular:
            traits = [.weight: UIFont.Weight.regular]
        case .medium:
            traits = [.weight: UIFont.Weight.medium]
        case .semibold:
            traits = [.weight: UIFont.Weight.semibold]
        case .bold:
            traits = [.weight: UIFont.Weight.bold]
        case .heavy:
            traits = [.weight: UIFont.Weight.heavy]
        case .black:
            traits = [.weight: UIFont.Weight.black]
        default:
            traits = [.weight: UIFont.Weight.regular]
        }

        let descriptor = self.fontDescriptor.addingAttributes([.traits: traits])
        return UIFont(descriptor: descriptor, size: self.pointSize)
    }
}
