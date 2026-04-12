import SwiftData
import SwiftUI

enum SourcePickerMode {
    case single(selectedID: PersistentIdentifier?, onSelect: (MediaSource) -> Void)
    case multi(selectedIDs: Binding<Set<PersistentIdentifier>>)
}

struct SourcePickerSheet: View {
    let sources: [MediaSource]
    let mode: SourcePickerMode

    @State private var gridPadding: CGFloat = 0

    private var title: String {
        switch self.mode {
        case .single: return "Select Source"
        case .multi: return "Filter Sources"
        }
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let pad = MediaSourceGridLayout.sidePadding(for: geometry.size.width)

                ScrollView {
                    MediaSourceGridView(sources: self.sources.sorted(by: { $0.order < $1.order })) { source in
                        self.sourceButton(source)
                    }
                    .padding(.top, -pad + 16)
                    .padding(.bottom, -pad)
                }
                .scrollIndicators(.hidden)
                .onAppear { self.gridPadding = pad }
                .onChange(of: geometry.size.width) { _, _ in self.gridPadding = pad }
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
        case let .multi(selectedIDs):
            return selectedIDs.wrappedValue.contains(source.persistentModelID)
        }
    }

    private func sourceButton(_ source: MediaSource) -> some View {
        Button {
            switch self.mode {
            case let .single(_, onSelect):
                onSelect(source)
            case let .multi(selectedIDs):
                if selectedIDs.wrappedValue.contains(source.persistentModelID) {
                    selectedIDs.wrappedValue.remove(source.persistentModelID)
                } else {
                    selectedIDs.wrappedValue.insert(source.persistentModelID)
                }
            }
        } label: {
            MediaSourceIcon(source: source, isSelected: self.isSelected(source))
        }
        .buttonStyle(.plain)
    }
}
