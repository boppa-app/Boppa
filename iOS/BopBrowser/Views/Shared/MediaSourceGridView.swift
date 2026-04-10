import SwiftUI

struct MediaSourceGridView<Content: View>: View {
    let sources: [MediaSource]
    @ViewBuilder let content: (MediaSource) -> Content

    static var iconSize: CGFloat {
        64
    }

    static var gridSpacing: CGFloat {
        24
    }

    static var minSidePadding: CGFloat {
        16
    }

    @State private(set) var padding: CGFloat = 0

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

    static func gridHeight(for width: CGFloat, sourceCount: Int) -> CGFloat {
        let sidePad = self.sidePadding(for: width)
        let cols = self.columnsForWidth(width)
        let rowCount = ceil(Double(sourceCount) / Double(cols))
        let contentHeight = CGFloat(rowCount) * self.iconSize + CGFloat(max(rowCount - 1, 0)) * self.gridSpacing
        return contentHeight + 2 * sidePad
    }

    var body: some View {
        GeometryReader { geometry in
            let cols = Self.columnsForWidth(geometry.size.width)
            let sidePad = Self.sidePadding(for: geometry.size.width)
            let rows = self.sources.chunked(into: cols)

            VStack(alignment: .leading, spacing: Self.gridSpacing) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: Self.gridSpacing) {
                        ForEach(row) { source in
                            self.content(source)
                        }
                    }
                }
            }
            .padding(.horizontal, sidePad)
            .padding(.vertical, sidePad)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onAppear {
                self.padding = sidePad
            }
            .onChange(of: geometry.size.width) { _, _ in
                self.padding = sidePad
            }
        }
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: self.count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, self.count)])
        }
    }
}
