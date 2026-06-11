import SwiftUI

enum MediaSourceGridLayout {
    static let iconSize: CGFloat = 64
    static let gridSpacing: CGFloat = 24
    static let minSidePadding: CGFloat = 16

    static func columnsForWidth(_ width: CGFloat) -> Int {
        guard width > 0 else { return 1 }
        let available = width - 2 * self.minSidePadding
        if available < self.iconSize { return 1 }
        return max(1, Int((available + self.gridSpacing) / (self.iconSize + self.gridSpacing)))
    }

    static func sidePadding(for width: CGFloat) -> CGFloat {
        let cols = self.columnsForWidth(width)
        let totalIconsWidth = CGFloat(cols) * self.iconSize + CGFloat(cols - 1) * self.gridSpacing
        return (width - totalIconsWidth) / 2
    }

    static func gridHeight(for width: CGFloat, mediaSourceCount: Int) -> CGFloat {
        let sidePad = self.sidePadding(for: width)
        let cols = self.columnsForWidth(width)
        let rowCount = ceil(Double(mediaSourceCount) / Double(cols))
        let contentHeight = CGFloat(rowCount) * self.iconSize + CGFloat(max(rowCount - 1, 0)) * self.gridSpacing
        return contentHeight + 2 * sidePad
    }
}

struct MediaSourceGridView<Content: View>: View {
    let mediaSources: [MediaSource]
    @ViewBuilder let content: (MediaSource) -> Content

    @State private(set) var padding: CGFloat = 0

    private typealias Layout = MediaSourceGridLayout

    var body: some View {
        GeometryReader { geometry in
            let cols = Layout.columnsForWidth(geometry.size.width)
            let sidePad = Layout.sidePadding(for: geometry.size.width)
            let rows = stride(from: 0, to: self.mediaSources.count, by: cols).map { rowStart in
                Array(self.mediaSources[rowStart ..< min(rowStart + cols, self.mediaSources.count)])
            }

            VStack(alignment: .leading, spacing: Layout.gridSpacing) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: Layout.gridSpacing) {
                        ForEach(row) { mediaSource in
                            self.content(mediaSource)
                        }
                    }
                }
            }
            .padding(.horizontal, sidePad)
            .padding(.vertical, sidePad)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onAppear { self.padding = sidePad }
            .onChange(of: geometry.size.width) { _, _ in
                self.padding = sidePad
            }
        }
    }
}
