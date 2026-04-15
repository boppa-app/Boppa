import SwiftData
import SwiftUI

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = LibraryViewModel()

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
            .onReceive(NotificationCenter.default.publisher(for: .mediaSourceUpdated)) { _ in
                self.viewModel.loadSources(modelContext: self.modelContext)
            }
            .sheet(isPresented: self.$viewModel.showFilterSheet) {
                MediaSourcePickerSheet(
                    mediaSources: self.viewModel.mediaSources,
                    mediaSourcePickerMode: .multi(selectedIDs: self.$viewModel.visibleSourceIDs)
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color(.systemGray6))
            }
        }
    }

    private var toolbar: some View {
        HStack {
            Text("Library")
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
        self.sectionList
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "bookmark")
                .font(.system(size: 40))
                .foregroundColor(Color(.systemGray5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var sectionList: some View {
        List {
            ForEach(LibraryViewModel.LibrarySection.allCases, id: \.self) { section in
                self.librarySection(section)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func librarySection(_ section: LibraryViewModel.LibrarySection) -> some View {
        let isCollapsed = self.viewModel.isCollapsed(section: section.rawValue)
        let items = self.viewModel.tracklistsForSection(section, modelContext: self.modelContext)

        return Section {
            if !isCollapsed {
                ForEach(Array(items.enumerated()), id: \.element.0.id) { index, item in
                    let (tracklist, mediaSource) = item
                    NavigationLink {
                        TracklistView(
                            tracklist: Tracklist(storedTracklist: tracklist)
                        )
                    } label: {
                        self.tracklistRow(tracklist, mediaSource: mediaSource, section: section)
                            .alignmentGuide(.listRowSeparatorTrailing) { $0[.trailing] }
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.black)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowSeparatorTint(index == items.count - 1 ? .clear : Color(.systemGray5))
                    .padding(.trailing, 16)
                }
            }
        } header: {
            self.sectionHeader(section: section, isCollapsed: isCollapsed)
        }
        .listSectionSeparator(.hidden)
    }

    private func sectionHeader(section: LibraryViewModel.LibrarySection, isCollapsed: Bool) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                self.viewModel.toggleCollapse(section: section.rawValue)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: section.icon)
                    .font(.system(size: 16))
                    .foregroundColor(.purp)
                    .frame(width: 24, height: 24)

                Text(section.displayName)
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .textCase(nil)
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
    }

    private var albumPlaceholder: String {
        if #available(iOS 26.0, *) {
            return "music.note.square.stack.fill"
        } else {
            return "square.stack.fill"
        }
    }

    private func tracklistRow(_ tracklist: StoredTracklist, mediaSource: MediaSource, section: LibraryViewModel.LibrarySection) -> some View {
        return HStack(spacing: 12) {
            ArtworkView(
                url: tracklist.artworkUrl,
                placeholder: section == .playlists ? "music.note.list" : self.albumPlaceholder,
                size: 72
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(tracklist.name)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)

                if let subtitle = tracklist.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(Color(.systemGray))
                        .lineLimit(1)
                }
            }

            Spacer()

            if let iconSvg = mediaSource.config.iconSvg {
                SVGImageView(svgString: iconSvg, size: 20)
                    .frame(width: 20, height: 20)
                    .opacity(0.5)
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 14))
                    .foregroundColor(.purp)
                    .frame(width: 20, height: 20)
                    .opacity(0.5)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

#Preview {
    LibraryView()
        .modelContainer(for: [MediaSource.self, StoredTracklist.self, StoredTrack.self], inMemory: true)
        .preferredColorScheme(.dark)
}
