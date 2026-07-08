import SwiftUI

private struct AlbumCardFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect?

    static func reduce(value: inout CGRect?, nextValue: () -> CGRect?) {
        if let next = nextValue() { value = next }
    }
}

struct RecentsSectionsView: View {
    let recentlyPlayedEntries: [RecentlyPlayedEntry]
    let recentlyViewed: [RecentlyViewedItem]
    let onSelectTrack: (Track) -> Void
    let onShowTrackActions: (Track) -> Void
    let onSelectArtist: (Artist) -> Void
    let onSelectTracklist: (Tracklist) -> Void
    let onClearRecentlyPlayed: () -> Void
    let onClearRecentlyViewed: () -> Void
    let animateChanges: Bool

    @State private var expandedEntryId: String?
    @State private var expandedAlbumCardFrame: CGRect?

    private var isEmpty: Bool {
        self.recentlyPlayedEntries.isEmpty && self.recentlyViewed.isEmpty
    }

    private var expandedAlbumGroup: RecentlyPlayedEntry.AlbumGroup? {
        guard let expandedEntryId else { return nil }
        for entry in self.recentlyPlayedEntries {
            if entry.id == expandedEntryId, case let .album(group) = entry {
                return group
            }
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if self.isEmpty {
                self.emptyState
            } else {
                Group {
                    if !self.recentlyPlayedEntries.isEmpty {
                        self.recentlyPlayedSection
                            .transition(.opacity)
                    }
                }
                .animation(
                    self.animateChanges ? .easeInOut(duration: 0.25) : nil,
                    value: self.recentlyPlayedEntries.isEmpty
                )

                if !self.recentlyPlayedEntries.isEmpty, !self.recentlyViewed.isEmpty {
                    self.separator
                }

                Group {
                    if !self.recentlyViewed.isEmpty {
                        self.recentlyViewedSection
                            .transition(.opacity)
                    }
                }
                .animation(
                    self.animateChanges ? .easeInOut(duration: 0.25) : nil,
                    value: self.recentlyViewed.isEmpty
                )
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
        VStack(alignment: .leading, spacing: 8) {
            self.sectionHeader(
                title: "Recently Played",
                accessibilityLabel: "Clear Recently Played",
                accessibilityHint: "Remove all recently played tracks",
                action: self.onClearRecentlyPlayed
            )
            GeometryReader { outerGeo in
                ScrollView(.horizontal) {
                    LazyHStack(alignment: .top, spacing: 16) {
                        ForEach(self.recentlyPlayedEntries) { entry in
                            switch entry {
                            case let .track(track):
                                RecentlyPlayedCard(
                                    track: track,
                                    isSelected: PlaybackService.shared.currentTrack?.url == track.url
                                        && track.url != nil,
                                    isLoading: PlaybackService.shared.isLoading,
                                    isPlaying: PlaybackService.shared.isPlaying,
                                    onTap: { self.onSelectTrack(track) },
                                    onShowActions: { self.onShowTrackActions(track) }
                                )
                            case let .album(group):
                                RecentlyPlayedAlbumCard(
                                    tracklist: group.tracklist,
                                    artworkUrls: group.tracks.map(\.displayArtworkUrl),
                                    onTap: {
                                        withAnimation(.easeInOut(duration: 0.25)) {
                                            self.expandedEntryId = self.expandedEntryId == entry.id ? nil : entry.id
                                        }
                                    }
                                )
                                .background(
                                    GeometryReader { cardGeo in
                                        Color.clear.preference(
                                            key: AlbumCardFramePreferenceKey.self,
                                            value: self.expandedEntryId == entry.id
                                                ? cardGeo.frame(in: .global)
                                                : nil
                                        )
                                    }
                                )
                                .onDisappear {
                                    if self.expandedEntryId == entry.id {
                                        withAnimation(.easeInOut(duration: 0.25)) {
                                            self.expandedEntryId = nil
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .scrollIndicators(.hidden)
                .onPreferenceChange(AlbumCardFramePreferenceKey.self) { globalFrame in
                    guard let globalFrame else {
                        self.expandedAlbumCardFrame = nil
                        return
                    }
                    let viewport = outerGeo.frame(in: .global)
                    self.expandedAlbumCardFrame = CGRect(
                        x: globalFrame.minX - viewport.minX,
                        y: globalFrame.minY - viewport.minY,
                        width: globalFrame.width,
                        height: globalFrame.height
                    )
                }
            }
            .frame(height: RecentlyPlayedCard.height)

            if self.expandedAlbumGroup != nil, let frame = self.expandedAlbumCardFrame {
                self.chevronToggle
                    .offset(x: frame.midX - 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
            }

            if let expandedGroup = self.expandedAlbumGroup {
                self.expandedTracksRow(expandedGroup)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private var chevronToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                self.expandedEntryId = nil
            }
        } label: {
            Image(systemName: "chevron.compact.up")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.purp)
                .frame(width: 32, height: 20)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Collapse")
        .accessibilityHint("Hide expanded album tracks")
    }

    private func expandedTracksRow(_ group: RecentlyPlayedEntry.AlbumGroup) -> some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 16) {
                ForEach(group.tracks) { track in
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
