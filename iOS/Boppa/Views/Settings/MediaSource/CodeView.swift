import Highlighter
import SwiftUI

struct CodeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.bottomBarInset) private var bottomBarInset
    @Environment(\.scrollFadeBottomInset) private var scrollFadeBottomInset
    let title: String
    let code: String
    @State private var headerFadeVisibility: CGFloat = 0

    var body: some View {
        ZStack(alignment: .top) {
            GeometryReader { geometry in
                EdgeFadeView(topFadeHeight: 0, bottomInset: self.scrollFadeBottomInset) {
                    ScrollView {
                        HighlightedTextView(code: self.code, width: geometry.size.width)
                    }
                    .contentMargins(.top, DetailHeaderMetrics.height, for: .scrollContent)
                    .contentMargins(.bottom, self.bottomBarInset, for: .scrollContent)
                    .reportsBottomScrollProximity()
                    .reportsScrollEdgeProximity(.top, visibility: self.$headerFadeVisibility)
                }
            }

            EdgeGradientFade(
                edge: .top,
                visibility: self.headerFadeVisibility,
                gradientExtension: DetailHeaderMetrics.fadeGradientExtension,
                solidExtent: DetailHeaderMetrics.fadeSolidExtent
            )

            DetailHeaderView(
                title: self.title,
                onBack: { self.dismiss() }
            )
        }
        .clipped()
        .navigationBarHidden(true)
        .enableSwipeBack()
        .allowsLandscape()
    }
}

struct HighlightedTextView: UIViewRepresentable {
    let code: String
    let width: CGFloat

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 12, bottom: 16, right: 12)

        if let highlighter = Highlighter() {
            highlighter.setTheme("atom-one-dark")
            if let attributed = highlighter.highlight(self.code, as: "javascript") {
                textView.attributedText = attributed
            } else {
                textView.text = self.code
                textView.textColor = .white
                textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
            }
        } else {
            textView.text = self.code
            textView.textColor = .white
            textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        }

        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.frame.size.width = self.width
        uiView.invalidateIntrinsicContentSize()
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: UITextView,
        context: Context
    ) -> CGSize? {
        let width = proposal.width ?? self.width
        let size = uiView.sizeThatFits(CGSize(
            width: width,
            height: CGFloat.greatestFiniteMagnitude
        ))
        return CGSize(width: width, height: size.height)
    }
}
