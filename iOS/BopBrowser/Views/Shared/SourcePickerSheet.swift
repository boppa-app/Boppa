import SwiftData
import SwiftUI

enum SourcePickerMode {
    case single(selectedID: PersistentIdentifier?, onSelect: (MediaSource) -> Void)
    case multi(selectedNames: Binding<Set<String>>)
}

struct SourcePickerSheet: View {
    let sources: [MediaSource]
    let mode: SourcePickerMode

    private var title: String {
        switch self.mode {
        case .single: return "Select Source"
        case .multi: return "Filter Sources"
        }
    }

    private let columns = [
        GridItem(.adaptive(minimum: 80, maximum: 100), spacing: 20),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: self.columns, spacing: 40) {
                    ForEach(self.sources) { source in
                        self.sourceCell(source)
                    }
                }
                .padding(20)
            }
            .navigationTitle(self.title)
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
        }
    }

    private func sourceCell(_ source: MediaSource) -> some View {
        let isSelected: Bool = {
            switch self.mode {
            case let .single(selectedID, _):
                return source.persistentModelID == selectedID
            case let .multi(selectedNames):
                return selectedNames.wrappedValue.contains(source.name)
            }
        }()

        return Button {
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
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.purp : Color(.systemGray2))
                        .fill(isSelected ? Color.purp.opacity(0.2) : Color(.systemGray6))
                        .frame(width: 64, height: 64)

                    if let iconSvg = source.config.iconSvg {
                        SVGImageView(svgString: iconSvg, size: 40)
                            .frame(width: 40, height: 40)
                            .opacity(isSelected ? 1.0 : 0.5)
                    } else {
                        Image(systemName: "music.note")
                            .font(.system(size: 24))
                            .foregroundColor(isSelected ? Color.purp : Color(.systemGray2))
                    }
                }
                Text(source.name)
                    .font(.caption)
                    .foregroundColor(isSelected ? .purp : Color(.systemGray2))
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}
