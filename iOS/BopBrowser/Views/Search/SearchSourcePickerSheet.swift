import SwiftData
import SwiftUI

struct SearchSourcePickerSheet: View {
    @Bindable var viewModel: SearchViewModel

    private let columns = [
        GridItem(.adaptive(minimum: 80, maximum: 100), spacing: 20),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: self.columns, spacing: 40) {
                    ForEach(self.viewModel.availableSources) { source in
                        self.sourceCell(source)
                    }
                }
                .padding(20)
            }
            .navigationTitle("Select Source")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.visible)
        }
        .background(Color(.systemBackground))
    }

    private func sourceCell(_ source: MediaSource) -> some View {
        let isSelected = source.persistentModelID == self.viewModel.selectedSource?.persistentModelID

        return Button {
            self.viewModel.selectSource(source)
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.purp : Color(.systemGray2))
                        .fill(isSelected ? Color.purp.opacity(0.2) : Color(.systemGray6))
                        .frame(width: 64, height: 64)

                    if let iconSvg = source.config?.iconSvg {
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
