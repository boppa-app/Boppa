import SwiftUI

struct VisualsPreferencesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.bottomBarInset) private var bottomBarInset
    @Environment(\.scrollFadeBottomInset) private var scrollFadeBottomInset
    @AppStorage(ArtworkMediaSourceRevealTrigger.storageKey) private var revealTriggerRaw =
        ArtworkMediaSourceRevealTrigger.defaultValue.rawValue
    @AppStorage(MediaSourceCapsuleVisibility.storageKey) private var capsuleVisibilityRaw =
        MediaSourceCapsuleVisibility.defaultValue.rawValue
    @State private var headerFadeVisibility: CGFloat = 0

    private var revealTrigger: Binding<ArtworkMediaSourceRevealTrigger> {
        Binding(
            get: {
                ArtworkMediaSourceRevealTrigger(rawValue: self.revealTriggerRaw) ?? .defaultValue
            },
            set: { self.revealTriggerRaw = $0.rawValue }
        )
    }

    private var capsuleVisibility: Binding<MediaSourceCapsuleVisibility> {
        Binding(
            get: {
                MediaSourceCapsuleVisibility(rawValue: self.capsuleVisibilityRaw) ?? .defaultValue
            },
            set: { self.capsuleVisibilityRaw = $0.rawValue }
        )
    }

    var body: some View {
        ZStack(alignment: .top) {
            EdgeFadeView(topFadeHeight: 0, bottomInset: self.scrollFadeBottomInset) {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Artwork Media Source Reveal")
                                .font(.body)
                                .foregroundColor(.primary)
                            ThreeWaySlider(selection: self.revealTrigger)
                                .accessibilityLabel("Artwork Media Source Reveal Trigger")
                        }
                        .padding(.vertical, 6)
                    } footer: {
                        Text(
                            "Choose how to reveal the media source for a track or tracklist by tapping on its artwork."
                        )
                    }

                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Media Source Capsule")
                                .font(.body)
                                .foregroundColor(.primary)
                            ThreeWaySlider(selection: self.capsuleVisibility)
                                .accessibilityLabel("Media Source Capsule Visibility")
                        }
                        .padding(.vertical, 6)
                    } footer: {
                        Text(
                            "Choose where to show the colored capsule that marks a track or tracklist's media source."
                        )
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
                title: "Visuals",
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
        VisualsPreferencesView()
    }
}
