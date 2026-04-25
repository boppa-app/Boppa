import SwiftUI

struct TracklistListActionSheet: View {
    let type: TracklistListType
    let sortMode: SortMode
    let onSortSelected: (SortMode) -> Void
    let onEdit: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showSortPage = false

    private var sortLabel: String {
        switch self.type {
        case .albums: return "Sort Albums"
        case .playlists: return "Sort Playlists"
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer().frame(height: 20)

                List {
                    self.editRow
                    self.sortRow
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .background(Color(.systemGray6))
            .navigationDestination(isPresented: self.$showSortPage) {
                self.sortPickerPage
            }
        }
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
                Text(self.sortLabel)
                    .font(.body)
                    .foregroundColor(.white)
                    .padding([.trailing], -12)
                if self.sortMode != .defaultOrder {
                    Text(" (\(self.sortMode.label))")
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

    private var editRow: some View {
        Button {
            self.onEdit()
            self.dismiss()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 16))
                    .foregroundColor(.purp)
                    .frame(width: 24)
                Text("Edit")
                    .font(.body)
                    .foregroundColor(.white)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(Color(.systemGray6))
        .listRowInsets(EdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20))
        .listRowSeparator(.hidden)
    }

    private var sortPickerPage: some View {
        let modes = SortMode.allCases.filter { $0 != .defaultOrder }

        return VStack(spacing: 0) {
            Spacer().frame(height: 20)
            ZStack {
                Text(self.sortLabel)
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
