import SwiftUI

struct AppearancePreferencesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.bottomBarInset) private var bottomBarInset
    @Environment(\.scrollFadeBottomInset) private var scrollFadeBottomInset
    @AppStorage(ArtworkMediaSourceRevealTrigger.storageKey) private var revealTriggerRaw =
        ArtworkMediaSourceRevealTrigger.defaultValue.rawValue
    @AppStorage(MediaSourceSeparatorVisibility.storageKey) private var separatorVisibilityRaw =
        MediaSourceSeparatorVisibility.defaultValue.rawValue
    @State private var headerFadeVisibility: CGFloat = 0

    private var revealTrigger: Binding<ArtworkMediaSourceRevealTrigger> {
        Binding(
            get: {
                ArtworkMediaSourceRevealTrigger(rawValue: self.revealTriggerRaw) ?? .defaultValue
            },
            set: { self.revealTriggerRaw = $0.rawValue }
        )
    }

    private var separatorVisibility: Binding<MediaSourceSeparatorVisibility> {
        Binding(
            get: {
                MediaSourceSeparatorVisibility(rawValue: self.separatorVisibilityRaw) ??
                    .defaultValue
            },
            set: { self.separatorVisibilityRaw = $0.rawValue }
        )
    }

    var body: some View {
        ZStack(alignment: .top) {
            EdgeFadeView(topFadeHeight: 0, bottomInset: self.scrollFadeBottomInset) {
                List {
                    Section("Media Source Indicators") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Artwork Media Source Reveal")
                                .font(.body)
                                .foregroundColor(.primary)
                            ThreeWaySlider(selection: self.revealTrigger)
                                .accessibilityLabel("Artwork Media Source Reveal Trigger")
                            Text(
                                "Choose how to reveal the media source for a track or tracklist by tapping on its artwork."
                            )
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 6)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Media Source Separator")
                                .font(.body)
                                .foregroundColor(.primary)
                            ThreeWaySlider(selection: self.separatorVisibility)
                                .accessibilityLabel("Media Source Separator Visibility")
                            Text(
                                "Choose where to show the colored separator that marks a track or tracklist's media source."
                            )
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 6)
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
                title: "Appearance",
                onBack: { self.dismiss() }
            )
        }
        .clipped()
        .navigationBarHidden(true)
        .enableSwipeBack()
    }
}

#Preview {
    NavigationStack {
        AppearancePreferencesView()
    }
}
