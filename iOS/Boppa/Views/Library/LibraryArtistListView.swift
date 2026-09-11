import SwiftUI

struct LibraryArtistListView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var artists: [StoredArtist] = []
    @State private var mediaSourcesById: [String: StoredMediaSource] = [:]
    @State private var mediaSourceConfigsById: [String: MediaSourceConfig] = [:]
    var navigationReset: NavigationResetSignal
    var onArtistSelected: (Artist, StoredMediaSource) -> Void

    init(
        navigationReset: NavigationResetSignal = NavigationResetSignal(),
        onArtistSelected: @escaping (Artist, StoredMediaSource) -> Void
    ) {
        self.navigationReset = navigationReset
        self.onArtistSelected = onArtistSelected
    }

    var body: some View {
        VStack(spacing: 0) {
            DetailHeaderView(
                title: "Artists",
                onBack: { self.dismiss() }
            )
            self.content
        }
        .navigationBarHidden(true)
        .enableSwipeBack()
        .onAppear { self.loadArtists() }
        .onReceive(NotificationCenter.default.publisher(for: .artistLibraryChanged)) { _ in
            self.loadArtists()
        }
    }

    private var content: some View {
        Group {
            if self.artists.isEmpty {
                self.emptyState
            } else {
                self.artistList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var artistList: some View {
        AlphabetIndexedList(items: self.artists, name: \.name) { stored in
            Button {
                guard let mediaSource = self.mediaSourcesById[stored.mediaSourceId] else {
                    return
                }
                self.onArtistSelected(stored.toArtist(), mediaSource)
            } label: {
                ArtistRow(
                    artist: stored.toArtist(),
                    showMediaSourceDivider: true,
                    showMediaSourceReveal: true,
                    revealConfig: self.mediaSourceConfigsById[stored.mediaSourceId]
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "zzz")
                .font(.system(size: 40))
                .foregroundColor(Color(.systemGray5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadArtists() {
        self.artists = ArtistStorageManager.shared.fetchLibraryArtists()
        let sources = MediaSourceStorageManager.shared.fetchAll()
        self.mediaSourcesById = Dictionary(uniqueKeysWithValues: sources.map { ($0.id, $0) })
        self.mediaSourceConfigsById = Dictionary(
            uniqueKeysWithValues: sources.map { ($0.id, $0.config) }
        )
    }
}
