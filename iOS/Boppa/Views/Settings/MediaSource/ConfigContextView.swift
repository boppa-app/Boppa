import SwiftUI

struct ConfigContextView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.bottomBarInset) private var bottomBarInset
    @Environment(\.scrollFadeBottomInset) private var scrollFadeBottomInset
    let contexts: [ContextConfig]
    @State private var headerFadeVisibility: CGFloat = 0

    var body: some View {
        ZStack(alignment: .top) {
            EdgeFadeView(topFadeHeight: 0, bottomInset: self.scrollFadeBottomInset) {
                List {
                    ForEach(Array(self.contexts.enumerated()), id: \.offset) { (
                        _: Int,
                        context: ContextConfig
                    ) in
                        Section(context.title) {
                            LabeledContent("URL", value: context.url)
                            LabeledContent(
                                "Interval",
                                value: Self.formatInterval(context.intervalSeconds)
                            )

                            if !context.userScripts.isEmpty {
                                ForEach(Array(context.userScripts.enumerated()), id: \.offset) { (
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
                title: "Context",
                onBack: { self.dismiss() }
            )
        }
        .clipped()
        .navigationBarHidden(true)
        .enableSwipeBack()
    }

    private static func formatInterval(_ seconds: Int) -> String {
        if seconds % 86400 == 0 {
            let days = seconds / 86400
            return days == 1 ? "1 day" : "\(days) days"
        } else if seconds % 3600 == 0 {
            let hours = seconds / 3600
            return hours == 1 ? "1 hour" : "\(hours) hours"
        } else if seconds % 60 == 0 {
            let minutes = seconds / 60
            return minutes == 1 ? "1 minute" : "\(minutes) minutes"
        } else {
            return seconds == 1 ? "1 second" : "\(seconds) seconds"
        }
    }
}
