import SwiftUI

struct TracklistListView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = TracklistListViewModel()
    @State private var selectedTracklistId: UUID?
    @State private var showActionSheet = false
    @State private var tracklistToDelete: Tracklist?

    let artist: Artist?
    let mediaSource: MediaSource?
    let type: TracklistListType
    let title: String
    let isLibraryMode: Bool
    let visibleMediaSourceIds: Set<String>

    init(
        artist: Artist,
        mediaSource: MediaSource,
        type: TracklistListType,
        title: String
    ) {
        self.artist = artist
        self.mediaSource = mediaSource
        self.type = type
        self.title = title
        self.isLibraryMode = false
        self.visibleMediaSourceIds = []
    }

    init(type: TracklistListType, title: String, visibleMediaSourceIds: Set<String>) {
        self.artist = nil
        self.mediaSource = nil
        self.type = type
        self.title = title
        self.isLibraryMode = true
        self.visibleMediaSourceIds = visibleMediaSourceIds
    }

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                DetailHeaderView(
                    title: self.title,
                    highlightedTitle: self.artist?.name,
                    onBack: {
                        if self.viewModel.isEditing {
                            self.viewModel.exitEditMode()
                        } else {
                            self.dismiss()
                        }
                    },
                    trailing: {
                        if self.isLibraryMode {
                            if self.viewModel.isEditing {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 16))
                                    .foregroundColor(.purp)
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        self.viewModel.exitEditMode()
                                    }
                                    .accessibilityLabel("Done Editing")
                                    .accessibilityHint("Exit edit mode")
                                    .accessibilityAddTraits(.isButton)
                            } else {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 16))
                                    .foregroundColor(.purp)
                                    .rotationEffect(.degrees(90))
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        self.showActionSheet = true
                                    }
                                    .accessibilityLabel("More Options")
                                    .accessibilityHint("Sort or edit this list")
                                    .accessibilityAddTraits(.isButton)
                            }
                        }
                    }
                )

                self.content
            }
        }
        .navigationBarHidden(true)
        .enableSwipeBack()
        .sheet(isPresented: self.$showActionSheet) {
            TracklistListActionSheet(
                type: self.type,
                sortMode: self.viewModel.sortMode,
                onSortSelected: { mode in
                    self.viewModel.setSortMode(mode, type: self.type)
                },
                onEdit: {
                    self.viewModel.enterEditMode(type: self.type)
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color(.systemGray6))
        }
        .alert("Remove From Library", isPresented: Binding(
            get: { self.tracklistToDelete != nil },
            set: { if !$0 { self.tracklistToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) {
                self.tracklistToDelete = nil
            }
            Button("Remove", role: .destructive) {
                if let tracklist = self.tracklistToDelete {
                    self.viewModel.deleteTracklistById(tracklist.id)
                    self.tracklistToDelete = nil
                }
            }
        } message: {
            if let tracklist = self.tracklistToDelete {
                Text("Are you sure you want to remove \"\(tracklist.title)\" from your library?")
            }
        }
        .onAppear {
            if self.isLibraryMode {
                self.viewModel.loadSortMode(type: self.type)
                self.viewModel.loadFromLibrary(
                    type: self.type,
                    visibleMediaSourceIds: self.visibleMediaSourceIds
                )
            } else if let artist = self.artist,
                      let mediaSource = self.mediaSource
            {
                self.viewModel.loadFromArtist(
                    type: self.type,
                    artist: artist,
                    mediaSource: mediaSource
                )
            }
        }
    }

    private var content: some View {
        Group {
            if let errorMessage = self.viewModel.errorMessage {
                self.errorView(message: errorMessage)
            } else if self.viewModel.tracklists.isEmpty && self.viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if self.viewModel.tracklists.isEmpty {
                self.emptyState
            } else {
                self.tracklistList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var canNavigateToTracklist: Bool {
        if self.isLibraryMode { return true }
        guard let mediaSource = self.mediaSource else { return false }
        switch self.type {
        case .albums:
            return mediaSource.config.list?.album != nil
        case .playlists:
            return mediaSource.config.list?.playlist != nil
        }
    }

    private var tracklistList: some View {
        ScrollFadeView {
            List {
                ForEach(self.viewModel.displayTracklists) { tracklist in
                    if self.viewModel.isEditing {
                        HStack(spacing: 0) {
                            Button {
                                self.viewModel.togglePin(tracklist: tracklist)
                            } label: {
                                Image(systemName: tracklist.storedTracklist?.isPinned == true ? "pin.slash.fill" : "pin.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(tracklist.storedTracklist?.isPinned == true ? .purp : Color(.systemGray))
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(tracklist.storedTracklist?.isPinned == true ? "Unpin \(tracklist.title)" : "Pin \(tracklist.title)")
                            .accessibilityHint(tracklist.storedTracklist?.isPinned == true ? "Remove from pinned" : "Add to pinned")

                            Button {
                                self.tracklistToDelete = tracklist
                            } label: {
                                Image(systemName: "bookmark.slash")
                                    .font(.system(size: 16))
                                    .foregroundColor(.red)
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove \(tracklist.title) from Library")
                            .accessibilityHint("Remove this tracklist from your library")

                            TracklistRow(tracklist: tracklist, showMediaSourceIcon: self.isLibraryMode)
                        }
                        .listRowBackground(Color.black)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowSeparator(.hidden)
                    } else {
                        TracklistRow(tracklist: tracklist, showMediaSourceIcon: self.isLibraryMode, showChevron: self.canNavigateToTracklist)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if self.canNavigateToTracklist {
                                    self.selectedTracklistId = tracklist.id
                                }
                            }
                            .background(
                                NavigationLink(
                                    destination: TracklistView(tracklist: tracklist),
                                    tag: tracklist.id,
                                    selection: self.$selectedTracklistId
                                ) { EmptyView() }
                                    .opacity(0)
                            )
                            .listRowBackground(Color.black)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .listRowSeparator(.hidden)
                    }
                }
                .onMove { source, destination in
                    self.viewModel.moveTracklist(from: source, to: destination)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.editMode, .constant(self.viewModel.isEditing ? .active : .inactive))
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

    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.red)
            Text(message)
                .font(.callout)
                .foregroundColor(Color(.systemGray))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
