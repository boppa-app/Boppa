import SwiftUI

struct ConfigPopupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.bottomBarInset) private var bottomBarInset
    @Environment(\.scrollFadeBottomInset) private var scrollFadeBottomInset
    let popups: [String: PopupConfig]
    @State private var headerFadeVisibility: CGFloat = 0

    var body: some View {
        ZStack(alignment: .top) {
            EdgeFadeView(topFadeHeight: 0, bottomInset: self.scrollFadeBottomInset) {
                List {
                    ForEach(Array(self.popups.sorted(by: { $0.key < $1.key })), id: \.key) { (
                        id: String,
                        popup: PopupConfig
                    ) in
                        Section(popup.title) {
                            LabeledContent("ID", value: id)
                            LabeledContent("URL", value: popup.url)

                            if !popup.userScripts.isEmpty {
                                ForEach(Array(popup.userScripts.enumerated()), id: \.offset) { (
                                    _: Int,
                                    script: Script
                                ) in
                                    NavigationLink(destination: CodeView(
                                        title: script.title,
                                        code: script.content
                                    )) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "scroll")
                                                .foregroundColor(.purp)
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(script.title)
                                                    .foregroundColor(.white)
                                                Text(
                                                    script.injectionTime == .atDocumentStart
                                                        ? "Runs At Document Start"
                                                        : "Runs At Document End"
                                                )
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .contentMargins(.top, DetailHeaderMetrics.height, for: .scrollContent)
                .contentMargins(.bottom, self.bottomBarInset, for: .scrollContent)
                .reportsBottomScrollProximity()
                .reportsScrollEdgeProximity(.top, visibility: self.$headerFadeVisibility)
            }

            EdgeGradientFade(
                edge: .top,
                visibility: self.headerFadeVisibility,
                gradientExtension: DetailHeaderMetrics.fadeGradientExtension,
                solidExtent: DetailHeaderMetrics.fadeSolidExtent
            )

            DetailHeaderView(
                title: "Popup",
                onBack: { self.dismiss() }
            )
        }
        .clipped()
        .navigationBarHidden(true)
        .enableSwipeBack()
    }
}
