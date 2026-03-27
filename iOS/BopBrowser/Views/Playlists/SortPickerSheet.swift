import SwiftUI

struct SortPickerSheet: View {
    let currentMode: TracklistSortMode
    let onSelect: (TracklistSortMode) -> Void

    private let modes = TracklistSortMode.allCases.filter { $0 != .defaultOrder }

    var body: some View {
        NavigationStack {
            List {
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
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color(.systemGray6))
                    .listRowInsets(EdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20))
                    .listRowSeparatorTint(mode == self.modes.first || mode == self.modes.last ? .clear : Color(.systemGray5))
                }
            }
            .listStyle(.plain)
            .navigationTitle("Sort By")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
        }
    }
}
