import SwiftUI

struct RecentsSectionsView: View {
    let recentlyPlayed: [Track]
    let recentlyViewed: [RecentlyViewedItem]
    let onSelectTrack: (Track) -> Void
    let onShowTrackActions: (Track) -> Void
    let onSelectArtist: (Artist) -> Void
    let onSelectTracklist: (Tracklist) -> Void
    let onClearRecentlyPlayed: () -> Void
    let onClearRecentlyViewed: () -> Void
    let animateChanges: Bool

    private var isEmpty: Bool {
        self.recentlyPlayed.isEmpty && self.recentlyViewed.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if self.isEmpty {
                self.emptyState
            } else {
                Group {
                    if !self.recentlyPlayed.isEmpty {
                        self.recentlyPlayedSection
                            .transition(.opacity)
                    }
                }
                .animation(self.animateChanges ? .easeInOut(duration: 0.25) : nil, value: self.recentlyPlayed.isEmpty)

                if !self.recentlyPlayed.isEmpty, !self.recentlyViewed.isEmpty {
                    self.separator
                }

                Group {
                    if !self.recentlyViewed.isEmpty {
                        self.recentlyViewedSection
                            .transition(.opacity)
                    }
                }
                .animation(self.animateChanges ? .easeInOut(duration: 0.25) : nil, value: self.recentlyViewed.isEmpty)
            }
        }
        .padding(.top, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(self.animateChanges ? .easeInOut(duration: 0.25) : nil, value: self.isEmpty)
    }

    private var separator: some View {
        Rectangle()
            .fill(Color(.systemGray6))
            .frame(height: 2)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
    }

    private var emptyState: some View {
        Image("Boppa-2")
            .resizable()
            .scaledToFit()
            .frame(width: 200, height: 200)
            .opacity(0.15)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var recentlyPlayedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            self.sectionHeader(
                title: "Recently Played",
                accessibilityLabel: "Clear Recently Played",
                accessibilityHint: "Remove all recently played tracks",
                action: self.onClearRecentlyPlayed
            )
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 16) {
                    ForEach(self.recentlyPlayed) { track in
                        RecentlyPlayedCard(
                            track: track,
                            isSelected: PlaybackService.shared.currentTrack?.url == track.url
                                && track.url != nil,
                            isLoading: PlaybackService.shared.isLoading,
                            isPlaying: PlaybackService.shared.isPlaying,
                            onTap: { self.onSelectTrack(track) },
                            onShowActions: { self.onShowTrackActions(track) }
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(height: RecentlyPlayedCard.height)
            .scrollIndicators(.hidden)
        }
    }

    private var recentlyViewedSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            self.sectionHeader(
                title: "Recently Viewed",
                accessibilityLabel: "Clear Recently Viewed",
                accessibilityHint: "Remove all recently viewed items",
                action: self.onClearRecentlyViewed
            )
            .padding(.bottom, 8)
            ScrollFadeView {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(self.recentlyViewed) { item in
                            Button {
                                switch item {
                                case let .artist(artist, _):
                                    self.onSelectArtist(artist)
                                case let .tracklist(tracklist, _):
                                    self.onSelectTracklist(tracklist)
                                }
                            } label: {
                                switch item {
                                case let .artist(artist, _):
                                    ArtistRow(artist: artist, showChevron: true)
                                case let .tracklist(tracklist, _):
                                    TracklistRow(
                                        tracklist: tracklist, showChevron: true, artworkSize: 48
                                    )
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func sectionHeader(
        title: String,
        accessibilityLabel: String,
        accessibilityHint: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 17))
                .fontWeight(.semibold)
                .foregroundColor(Color(.systemGray))
            Spacer()
            Button(action: action) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 17))
                    .foregroundColor(Color(.systemGray))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint(accessibilityHint)
        }
        .padding(.horizontal, 16)
    }
}
