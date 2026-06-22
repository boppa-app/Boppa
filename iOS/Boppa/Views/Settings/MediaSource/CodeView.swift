import Highlighter
import SwiftUI

struct CodeView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let code: String

    var body: some View {
        VStack(spacing: 0) {
            DetailHeaderView(
                title: self.title,
                onBack: { self.dismiss() }
            )

            GeometryReader { geometry in
                ScrollFadeView {
                    ScrollView {
                        HighlightedTextView(code: self.code, width: geometry.size.width)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .enableSwipeBack()
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

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? self.width
        let size = uiView.sizeThatFits(CGSize(width: width, height: CGFloat.greatestFiniteMagnitude))
        return CGSize(width: width, height: size.height)
    }
}
