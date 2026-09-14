import SwiftUI

struct ConfigPlaybackView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.bottomBarInset) private var bottomBarInset
    @Environment(\.scrollFadeBottomInset) private var scrollFadeBottomInset
    let playback: PlaybackConfig
    @State private var headerFadeVisibility: CGFloat = 0

    var body: some View {
        ZStack(alignment: .top) {
            EdgeFadeView(topFadeHeight: 0, bottomInset: self.scrollFadeBottomInset) {
                List {
                    if let url = self.playback.url {
                        Section("URL") {
                            Text(url)
                                .foregroundColor(.white)
                        }
                    }

                    if let html = self.playback.html {
                        Section("HTML") {
                            NavigationLink(destination: CodeView(
                                title: "HTML",
                                code: html
                            )) {
                                HStack(spacing: 8) {
                                    Image(systemName: "doc.richtext")
                                        .foregroundColor(.purp)
                                    Text("View HTML")
                                        .foregroundColor(.white)
                                }
                            }
                        }
                    }

                    if !self.playback.userScripts.isEmpty {
                        Section("Scripts") {
                            ForEach(Array(self.playback.userScripts.enumerated()), id: \.offset) { (
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
                title: "Playback",
                onBack: { self.dismiss() }
            )
        }
        .clipped()
        .navigationBarHidden(true)
        .enableSwipeBack()
    }
}
