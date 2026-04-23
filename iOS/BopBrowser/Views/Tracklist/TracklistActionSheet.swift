import SwiftUI

struct TracklistActionSheet: View {
    let tracklist: Tracklist
    let mediaSource: MediaSource?
    let isPinned: Bool
    let isRefreshing: Bool
    let sortMode: TracklistSortMode
    let onPin: () -> Void
    let onRefresh: () -> Void
    let onSortSelected: (TracklistSortMode) -> Void
    let onArtistSelected: ((Artist) -> Void)?
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showSortPage = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                self.header
                    .padding(.top, 20)
                    .padding(.bottom, 12)

                List {
                    self.refreshRow
                    self.pinRow
                    self.sortRow
                    self.artistRow
                    self.deleteRow
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .background(Color(.systemGray6))
            .navigationDestination(isPresented: self.$showSortPage) {
                self.sortPickerPage
            }
            .alert("Remove from library", isPresented: self.$showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Remove", role: .destructive) {
                    self.onDelete()
                    self.dismiss()
                }
            } message: {
                Text("Are you sure you want to remove \"\(self.tracklist.title)\" from your library?")
            }
        }
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                ArtworkView(url: self.tracklist.artworkUrl, placeholder: "music.note.list", size: 56)
                VStack(alignment: .leading, spacing: 4) {
                    MarqueeText(
                        self.tracklist.title,
                        font: .title3,
                        fontWeight: .semibold
                    )
                    if let subtitle = self.tracklist.subtitle {
                        MarqueeText(
                            subtitle,
                            font: .subheadline,
                            foregroundColor: Color(.systemGray)
                        )
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 28)

            Rectangle()
                .fill(Color(.systemGray5))
                .frame(height: 2)
                .padding(.horizontal, 16)
        }
    }

    private var pinRow: some View {
        Button {
            self.onPin()
            self.dismiss()
        } label: {
            self.rowLabel(
                title: self.isPinned ? "Unpin" : "Pin",
                icon: self.isPinned ? "pin.slash.fill" : "pin.fill",
                iconColor: self.isPinned ? .purp : .white
            )
        }
        .buttonStyle(.plain)
        .listRowBackground(Color(.systemGray6))
        .listRowInsets(EdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20))
        .listRowSeparator(.hidden)
    }

    private var refreshRow: some View {
        Button {
            self.onRefresh()
            self.dismiss()
        } label: {
            HStack(spacing: 12) {
                Group {
                    if self.isRefreshing {
                        ProgressView()
                            .scaleEffect(0.6)
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16))
                            .foregroundColor(.purp)
                    }
                }
                .frame(width: 24)
                Text("Refresh")
                    .font(.body)
                    .foregroundColor(self.isRefreshing ? Color(.systemGray) : .white)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(self.isRefreshing)
        .listRowBackground(Color(.systemGray6))
        .listRowInsets(EdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20))
        .listRowSeparator(.hidden)
    }

    private var sortRow: some View {
        Button {
            self.showSortPage = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 16))
                    .foregroundColor(self.sortMode == .defaultOrder ? .white : .purp)
                    .frame(width: 24)
                Text("Sort Tracks")
                    .font(.body)
                    .foregroundColor(.white)
                    .padding([.trailing], -12)
                if self.sortMode != .defaultOrder {
                    Text(" (\(self.sortMode.label)")
                        .font(.body)
                        .foregroundColor(.purp)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.purp)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(Color(.systemGray6))
        .listRowInsets(EdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20))
        .listRowSeparator(.hidden)
    }

    @ViewBuilder
    private var artistRow: some View {
        if self.mediaSource?.config.data?.getArtist != nil {
            ForEach(self.tracklist.artists) { artist in
                Button {
                    self.dismiss()
                    self.onArtistSelected?(artist)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.purp)
                            .frame(width: 24)
                        (
                            Text("Go to ")
                                .italic()
                                .foregroundColor(.white)
                                + Text(artist.name)
                                .bold()
                                .foregroundColor(.purp)
                        )
                        .font(.body)
                        .lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.purp)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(Color(.systemGray6))
                .listRowInsets(EdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20))
                .listRowSeparator(.hidden)
            }
        }
    }

    private var deleteRow: some View {
        Button {
            self.showDeleteConfirmation = true
        } label: {
            self.rowLabel(
                title: "Remove from library",
                icon: "bookmark.slash",
                iconColor: .red,
                titleColor: .red
            )
        }
        .buttonStyle(.plain)
        .listRowBackground(Color(.systemGray6))
        .listRowInsets(EdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20))
        .listRowSeparator(.hidden)
    }

    private func rowLabel<Trailing: View>(
        title: String,
        icon: String,
        iconColor: Color = .purp,
        titleColor: Color = .white,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(iconColor)
                .frame(width: 24)
            Text(title)
                .font(.body)
                .foregroundColor(titleColor)
            Spacer()
            trailing()
        }
        .contentShape(Rectangle())
    }

    private var sortPickerPage: some View {
        let modes = TracklistSortMode.allCases.filter { $0 != .defaultOrder }

        return VStack(spacing: 0) {
            Spacer().frame(height: 20)
            ZStack {
                Text("Sort By")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                HStack {
                    Button {
                        self.showSortPage = false
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .foregroundColor(.purp)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    Spacer()
                }
                .padding(.horizontal, 4)
            }
            .frame(height: 44)

            List {
                ForEach(modes, id: \.self) { mode in
                    Button {
                        self.onSortSelected(mode)
                        self.dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 16))
                                .foregroundColor(.purp)
                                .frame(width: 24)

                            Text(mode.label)
                                .font(.body)
                                .foregroundColor(self.sortMode == mode ? .purp : .white)

                            Spacer()

                            if self.sortMode == mode {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.purp)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color(.systemGray6))
                    .listRowInsets(EdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20))
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .navigationBarHidden(true)
        .background(Color(.systemGray6))
    }
}
