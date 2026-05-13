import SwiftData
import SwiftUI

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = LibraryViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                self.toolbar
                self.sectionList
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
            .onReceive(NotificationCenter.default.publisher(for: .tracklistPinChanged)) { _ in
                self.viewModel.loadPinnedTracklists(modelContext: self.modelContext)
            }
            .sheet(isPresented: self.$viewModel.showFilterSheet) {
                MediaSourcePickerSheet(
                    mediaSources: self.viewModel.mediaSources,
                    mediaSourcePickerMode: .multi(selectedMediaSourceIds: self.$viewModel.visibleMediaSourceIds)
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
            Button {
                self.viewModel.showFilterSheet = true
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 20))
                    .foregroundColor(.purp)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var sectionList: some View {
        ScrollFadeView {
            List {
                self.pinnedHeader
                    .listRowBackground(Color.black)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowSeparator(.hidden)

                if self.viewModel.isPinnedExpanded {
                    if self.viewModel.pinnedTracklists.isEmpty {
                        Image(systemName: "zzz")
                            .font(.system(size: 20))
                            .foregroundColor(Color(.systemGray3))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 12)
                            .padding(.leading, 76)
                            .padding(.trailing, 16)
                            .listRowBackground(Color.black)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .listRowSeparator(.hidden)
                    } else {
                        ForEach(Array(self.viewModel.pinnedTracklists.enumerated()), id: \.element.id) { _, stored in
                            TracklistRow(
                                tracklist: Tracklist(storedTracklist: stored),
                                showMediaSourceIcon: true,
                                showChevron: true
                            )
                            .background(
                                NavigationLink(destination: TracklistView(tracklist: Tracklist(storedTracklist: stored))) { EmptyView() }
                                    .opacity(0)
                            )
                            .listRowBackground(Color.black)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .listRowSeparator(.hidden)
                        }
                    }
                }

                ForEach(LibraryViewModel.LibrarySection.allCases, id: \.self) { section in
                    self.sectionButton(section)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    private var pinnedHeader: some View {
        Button {
            withAnimation {
                self.viewModel.isPinnedExpanded.toggle()
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "pin.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.purp)
                    .frame(width: 48, height: 48)
                Text("Pinned")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Image(systemName: self.viewModel.isPinnedExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(.systemGray))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black)
            .contentShape(Rectangle())
        }
    }

    private func sectionButton(_ section: LibraryViewModel.LibrarySection) -> some View {
        HStack(spacing: 12) {
            Image(systemName: section.icon)
                .font(.system(size: 16))
                .foregroundColor(.purp)
                .frame(width: 48, height: 48)

            Text(section.displayName)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.purp)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black)
        .contentShape(Rectangle())
        .background(
            NavigationLink(destination: self.destinationView(for: section)) { EmptyView() }
                .opacity(0)
        )
        .listRowBackground(Color.black)
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        .listRowSeparator(.hidden)
    }

    @ViewBuilder
    private func destinationView(for section: LibraryViewModel.LibrarySection) -> some View {
        let visibleIds = self.viewModel.visibleMediaSourceStringIds
        switch section {
        case .likes:
            TracklistView(
                tracklist: Tracklist(
                    id: "likes",
                    mediaSourceId: "",
                    title: "Likes",
                    tracklistType: .likes
                )
            )
        case .playlists:
            TracklistListView(type: .playlists, title: "Playlists", visibleMediaSourceIds: visibleIds)
        case .albums:
            TracklistListView(type: .albums, title: "Albums", visibleMediaSourceIds: visibleIds)
        }
    }
}

#Preview {
    LibraryView()
        .modelContainer(for: [MediaSource.self, StoredTracklist.self, StoredTrack.self], inMemory: true)
        .preferredColorScheme(.dark)
}
