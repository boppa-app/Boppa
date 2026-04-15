import SwiftData
import SwiftUI

enum MediaSourcePickerMode {
    case single(selectedID: PersistentIdentifier?, onSelect: (MediaSource) -> Void)
    case multi(selectedIDs: Binding<Set<PersistentIdentifier>>)
}

struct MediaSourcePickerSheet: View {
    let mediaSources: [MediaSource]
    let mediaSourcePickerMode: MediaSourcePickerMode

    @State private var gridPadding: CGFloat = 0

    private var title: String {
        switch self.mediaSourcePickerMode {
        case .single: return "Select Source"
        case .multi: return "Filter Sources"
        }
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let pad = MediaSourceGridLayout.sidePadding(for: geometry.size.width)

                ScrollView {
                    MediaSourceGridView(mediaSources: self.mediaSources.sorted(by: { $0.order < $1.order })) { mediaSources in
                        self.mediaSourceButton(mediaSources)
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

    private func isSelected(_ mediaSource: MediaSource) -> Bool {
        switch self.mediaSourcePickerMode {
        case let .single(selectedID, _):
            return mediaSource.persistentModelID == selectedID
        case let .multi(selectedIDs):
            return selectedIDs.wrappedValue.contains(mediaSource.persistentModelID)
        }
    }

    private func mediaSourceButton(_ mediaSource: MediaSource) -> some View {
        Button {
            switch self.mediaSourcePickerMode {
            case let .single(_, onSelect):
                onSelect(mediaSource)
            case let .multi(selectedIDs):
                if selectedIDs.wrappedValue.contains(mediaSource.persistentModelID) {
                    selectedIDs.wrappedValue.remove(mediaSource.persistentModelID)
                } else {
                    selectedIDs.wrappedValue.insert(mediaSource.persistentModelID)
                }
            }
        } label: {
            MediaSourceIcon(mediaSource: mediaSource, isSelected: self.isSelected(mediaSource))
        }
        .buttonStyle(.plain)
    }
}
