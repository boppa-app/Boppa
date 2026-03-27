import SwiftData
import SwiftUI

struct PlaylistsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = PlaylistsViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                self.toolbar
                self.content
            }
            .onAppear {
                self.viewModel.loadSources(modelContext: self.modelContext)
            }
            .onReceive(NotificationCenter.default.publisher(for: .mediaSourceAdded)) { _ in
                self.viewModel.loadSources(modelContext: self.modelContext)
            }
            .onReceive(NotificationCenter.default.publisher(for: .mediaSourceRemoved)) { _ in
                self.viewModel.loadSources(modelContext: self.modelContext)
            }
            .sheet(isPresented: self.$viewModel.showFilterSheet) {
                SourcePickerSheet(
                    sources: self.viewModel.mediaSources,
                    mode: .multi(selectedNames: self.$viewModel.visibleSourceNames)
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color(.systemGray6))
            }
        }
    }

    private var toolbar: some View {
        HStack {
            Text("Playlists")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
            Spacer()
            Button {
                self.viewModel.showFilterSheet = true
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 20))
                    .foregroundColor(.purp)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var content: some View {
        Group {
            if self.viewModel.filteredSources.isEmpty {
                self.emptyState
            } else {
                self.sourceList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // TODO: On empty playlists button to go to settings to add media source config
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note.list")
                .font(.system(size: 40))
                .foregroundColor(Color(.systemGray5))
            Text("No playlists yet")
                .font(.callout)
                .foregroundColor(Color(.systemGray))
        }
    }

    private var sourceList: some View {
        ScrollFadeView {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(self.viewModel.filteredSources) { source in
                        self.sourceSection(source)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func sourceSection(_ source: MediaSource) -> some View {
        let isCollapsed = self.viewModel.isCollapsed(sourceName: source.name)
        let playlists = self.viewModel.playlistsForSource(source, modelContext: self.modelContext)

        if !playlists.isEmpty {
            VStack(spacing: 0) {
                self.sectionHeader(source: source, isCollapsed: isCollapsed)

                if !isCollapsed {
                    ForEach(Array(playlists.enumerated()), id: \.element.id) { index, playlist in
                        NavigationLink {
                            TracklistView(
                                tracklist: Tracklist(storedTracklist: playlist),
                                source: source
                            )
                        } label: {
                            self.playlistRow(playlist)
                        }
                        .buttonStyle(.plain)

                        if index < playlists.count - 1 {
                            Divider()
                                .background(Color(.systemGray5))
                        }
                    }
                }
            }
        }
    }

    private func sectionHeader(source: MediaSource, isCollapsed: Bool) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                self.viewModel.toggleCollapse(sourceName: source.name)
            }
        } label: {
            HStack(spacing: 12) {
                if let iconSvg = source.config.iconSvg {
                    SVGImageView(svgString: iconSvg, size: 24)
                        .frame(width: 24, height: 24)
                } else {
                    Image(systemName: "music.note")
                        .font(.system(size: 16))
                        .foregroundColor(.purp)
                        .frame(width: 24, height: 24)
                }

                Text(source.name)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(.systemGray))
                    .rotationEffect(.degrees(isCollapsed ? 0 : 90))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(.systemGray6).opacity(0.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func playlistRow(_ playlist: StoredTracklist) -> some View {
        HStack(spacing: 12) {
            Text(playlist.name)
                .font(.body)
                .fontWeight(playlist.isLikes ? .bold : .regular)
                .foregroundColor(.white)
                .lineLimit(1)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(Color(.systemGray3))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

#Preview {
    PlaylistsView()
        .modelContainer(for: [MediaSource.self, StoredTracklist.self, StoredSong.self], inMemory: true)
        .preferredColorScheme(.dark)
}
