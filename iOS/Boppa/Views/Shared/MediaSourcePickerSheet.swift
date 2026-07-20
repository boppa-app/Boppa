import SwiftUI

enum MediaSourcePickerMode {
    case single(selectedID: String?, onSelect: (StoredMediaSource) -> Void)
    case multi(selectedMediaSourceIds: Binding<Set<String>>)
}

struct MediaSourcePickerSheet: View {
    let mediaSourcePickerMode: MediaSourcePickerMode

    @State private var mediaSources: [StoredMediaSource] = []
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
                    MediaSourceGridView(mediaSources: self.mediaSources) { mediaSources in
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
        .onAppear {
            self.mediaSources = MediaSourceStorageManager.shared.fetchAllEnabled()
        }
    }

    private func isSelected(_ mediaSource: StoredMediaSource) -> Bool {
        switch self.mediaSourcePickerMode {
        case let .single(selectedID, _):
            return mediaSource.id == selectedID
        case let .multi(selectedMediaSourceIds):
            return selectedMediaSourceIds.wrappedValue.contains(mediaSource.id)
        }
    }

    private func mediaSourceButton(_ mediaSource: StoredMediaSource) -> some View {
        Button {
            switch self.mediaSourcePickerMode {
            case let .single(_, onSelect):
                onSelect(mediaSource)
            case let .multi(selectedMediaSourceIds):
                if selectedMediaSourceIds.wrappedValue.contains(mediaSource.id) {
                    selectedMediaSourceIds.wrappedValue.remove(mediaSource.id)
                } else {
                    selectedMediaSourceIds.wrappedValue.insert(mediaSource.id)
                }
            }
        } label: {
            MediaSourceIcon(mediaSource: mediaSource, isSelected: self.isSelected(mediaSource))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mediaSource.config.name)
        .accessibilityHint(self.isSelected(mediaSource) ? "Selected, tap to deselect" : "Tap to select")
    }
}
