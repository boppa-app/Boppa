import SwiftData
import SwiftUI

enum SourcePickerMode {
    case single(selectedID: PersistentIdentifier?, onSelect: (MediaSource) -> Void)
    case multi(selectedNames: Binding<Set<String>>)
}

struct SourcePickerSheet: View {
    let sources: [MediaSource]
    let mode: SourcePickerMode

    private let iconSize: CGFloat = 64
    private let gridSpacing: CGFloat = 24
    private let minSidePadding: CGFloat = 16

    private var title: String {
        switch self.mode {
        case .single: return "Select Source"
        case .multi: return "Filter Sources"
        }
    }

    private func columnsForWidth(_ width: CGFloat) -> Int {
        guard width > 0 else { return 1 }
        let available = width - 2 * self.minSidePadding
        if available < self.iconSize { return 1 }
        return max(1, Int((available + self.gridSpacing) / (self.iconSize + self.gridSpacing)))
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let cols = self.columnsForWidth(geometry.size.width)
                let totalIconsWidth = CGFloat(cols) * self.iconSize + CGFloat(cols - 1) * self.gridSpacing
                let sidePadding = (geometry.size.width - totalIconsWidth) / 2

                let sortedSources = self.sources.sorted(by: { $0.order < $1.order })
                let rows = sortedSources.chunked(into: cols)

                ScrollView {
                    VStack(alignment: .leading, spacing: self.gridSpacing) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                            HStack(spacing: self.gridSpacing) {
                                ForEach(row) { source in
                                    self.sourceButton(source)
                                }
                            }
                        }
                    }
                    .padding(.top, 16)
                    .padding(.horizontal, sidePadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle(self.title)
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
        }
    }

    private func isSelected(_ source: MediaSource) -> Bool {
        switch self.mode {
        case let .single(selectedID, _):
            return source.persistentModelID == selectedID
        case let .multi(selectedNames):
            return selectedNames.wrappedValue.contains(source.name)
        }
    }

    private func sourceButton(_ source: MediaSource) -> some View {
        Button {
            switch self.mode {
            case let .single(_, onSelect):
                onSelect(source)
            case let .multi(selectedNames):
                if selectedNames.wrappedValue.contains(source.name) {
                    selectedNames.wrappedValue.remove(source.name)
                } else {
                    selectedNames.wrappedValue.insert(source.name)
                }
            }
        } label: {
            MediaSourceIcon(source: source, isSelected: self.isSelected(source))
        }
        .buttonStyle(.plain)
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: self.count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, self.count)])
        }
    }
}
