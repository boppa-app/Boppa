import SwiftUI

struct DetailHeaderView<CenterLeadingContent: View, TrailingContent: View, CenterContent: View>: View {
    let title: String
    let highlightedTitle: String?
    let onBack: () -> Void
    @ViewBuilder let centerLeading: () -> CenterLeadingContent
    @ViewBuilder let trailing: () -> TrailingContent
    @ViewBuilder let centerTrailing: () -> CenterContent

    init(
        title: String,
        highlightedTitle: String? = nil,
        onBack: @escaping () -> Void,
        @ViewBuilder centerLeading: @escaping () -> CenterLeadingContent = { EmptyView() },
        @ViewBuilder trailing: @escaping () -> TrailingContent = { EmptyView() },
        @ViewBuilder centerTrailing: @escaping () -> CenterContent = { EmptyView() }
    ) {
        self.title = title
        self.highlightedTitle = highlightedTitle
        self.onBack = onBack
        self.centerLeading = centerLeading
        self.trailing = trailing
        self.centerTrailing = centerTrailing
    }

    private let buttonWidth: CGFloat = 48
    private let progressViewSize: CGFloat = 20

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                let reservedPerSide = self.buttonWidth + self.progressViewSize * 1.5
                let maxTextWidth = max(geometry.size.width - reservedPerSide * 2, 0)

                ZStack {
                    HStack(spacing: 6) {
                        self.centerLeading()
                        MarqueeText(
                            self.title,
                            highlightedPrefix: self.highlightedTitle,
                            font: .headline,
                            fontWeight: .bold,
                            foregroundColor: .white,
                            maxWidth: maxTextWidth,
                            alignment: .center
                        )
                        self.centerTrailing()
                    }

                    HStack(spacing: 0) {
                        Button(action: self.onBack) {
                            Image(systemName: "chevron.left")
                                .font(.body.weight(.semibold))
                                .foregroundColor(Color.purp)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }

                        Spacer()

                        self.trailing()
                    }
                    .padding(.horizontal, 4)
                }
            }
            .frame(height: 44)
        }
    }
}
