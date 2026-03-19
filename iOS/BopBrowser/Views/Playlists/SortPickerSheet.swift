import SwiftUI

struct SortPickerSheet: View {
    let currentMode: PlaylistSortMode
    let onSelect: (PlaylistSortMode) -> Void

    private let modes = PlaylistSortMode.allCases.filter { $0 != .defaultOrder }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(self.modes, id: \.self) { mode in
                        Button {
                            self.onSelect(mode)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: mode.icon)
                                    .font(.system(size: 16))
                                    .foregroundColor(self.currentMode == mode ? .purp : Color(.systemGray))
                                    .frame(width: 24)

                                Text(mode.label)
                                    .font(.body)
                                    .foregroundColor(self.currentMode == mode ? .purp : .white)

                                Spacer()

                                if self.currentMode == mode {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.purp)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if mode != self.modes.last {
                            Divider().background(Color(.systemGray5))
                        }
                    }
                }
            }
            .navigationTitle("Sort By")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
        }
    }
}
