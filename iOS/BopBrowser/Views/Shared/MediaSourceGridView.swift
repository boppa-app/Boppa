import SwiftData
import SwiftUI

enum MediaSourceGridLayout {
    static let iconSize: CGFloat = 64
    static let gridSpacing: CGFloat = 24
    static let minSidePadding: CGFloat = 16
    static let hintTextHeight: CGFloat = 36

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

    static func gridHeight(for width: CGFloat, sourceCount: Int, isEditing: Bool = false) -> CGFloat {
        let sidePad = self.sidePadding(for: width)
        let cols = self.columnsForWidth(width)
        let itemCount = isEditing ? sourceCount + 1 : sourceCount
        let rowCount = ceil(Double(itemCount) / Double(cols))
        let contentHeight = CGFloat(rowCount) * self.iconSize + CGFloat(max(rowCount - 1, 0)) * self.gridSpacing
        let editingExtra: CGFloat = isEditing ? self.hintTextHeight : 0
        return contentHeight + 2 * sidePad + editingExtra
    }

    static func positionForIndex(_ index: Int, cols: Int) -> CGPoint {
        let row = index / cols
        let col = index % cols
        let x = CGFloat(col) * (iconSize + self.gridSpacing) + self.iconSize / 2
        let y = CGFloat(row) * (iconSize + self.gridSpacing) + self.iconSize / 2
        return CGPoint(x: x, y: y)
    }
}

struct MediaSourceGridView<Content: View>: View {
    let sources: [MediaSource]
    var isEditing: Bool = false
    var onReorder: ((_ from: Int, _ to: Int) -> Void)?
    var onAdd: (() -> Void)?
    var onDragStateChanged: ((_ isDragging: Bool) -> Void)?
    @ViewBuilder let content: (MediaSource) -> Content

    @State private(set) var padding: CGFloat = 0
    @State private var draggingID: PersistentIdentifier?
    @State private var dragPosition: CGPoint = .zero
    @State private var isReturningToSlot = false
    @State private var holdTimer: DispatchWorkItem?

    private typealias Layout = MediaSourceGridLayout

    var body: some View {
        GeometryReader { geometry in
            let cols = Layout.columnsForWidth(geometry.size.width)
            let sidePad = Layout.sidePadding(for: geometry.size.width)

            ZStack(alignment: .topLeading) {
                ForEach(Array(self.sources.enumerated()), id: \.element.id) { index, source in
                    self.sourceItemView(source, at: index, cols: cols, sidePad: sidePad, geometrySize: geometry.size)
                }

                if self.isEditing, self.onAdd != nil {
                    let addPos = Layout.positionForIndex(self.sources.count, cols: cols)
                    self.addButtonView
                        .frame(width: Layout.iconSize, height: Layout.iconSize)
                        .position(addPos)
                        .transition(.opacity)
                }
            }
            .overlay(alignment: .bottom) {
                if self.isEditing {
                    Text("Hold and Drag to Reorder")
                        .font(.caption)
                        .foregroundColor(Color(.systemGray))
                        .transition(.opacity)
                }
            }
            .coordinateSpace(name: "mediaSourceGrid")
            .padding(.horizontal, sidePad)
            .padding(.vertical, sidePad)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .onAppear { self.padding = sidePad }
            .onChange(of: geometry.size.width) { _, _ in
                self.padding = sidePad
            }
        }
    }

    private func sourceItemView(
        _ source: MediaSource,
        at index: Int,
        cols: Int,
        sidePad: CGFloat,
        geometrySize: CGSize
    ) -> some View {
        let gridPos = Layout.positionForIndex(index, cols: cols)
        let isDragging = self.draggingID == source.persistentModelID
        let anyDragging = self.draggingID != nil

        return self.content(source)
            .frame(width: Layout.iconSize, height: Layout.iconSize)
            .contentShape(Rectangle())
            .scaleEffect(isDragging ? 1.15 : 1.0, anchor: .center)
            .opacity(!isDragging && anyDragging ? 0.4 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isDragging)
            .animation(.easeInOut(duration: 0.15), value: anyDragging)
            .position(isDragging ? self.dragPosition : gridPos)
            .zIndex(isDragging ? 100 : 0)
            .animation(isDragging ? nil : .easeInOut(duration: 0.55), value: gridPos.x)
            .animation(isDragging ? nil : .easeInOut(duration: 0.55), value: gridPos.y)
            .applyIf(self.isEditing) { view in
                view.simultaneousGesture(
                    self.reorderDragGesture(
                        for: source,
                        at: index,
                        cols: cols,
                        sidePad: sidePad,
                        geometrySize: geometrySize
                    )
                )
            }
    }

    private var addButtonView: some View {
        Button {
            self.onAdd?()
        } label: {
            ZStack {
                Circle()
                    .strokeBorder(Color.purp.opacity(0.6), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .frame(width: Layout.iconSize, height: Layout.iconSize)

                Image(systemName: "plus")
                    .font(.system(size: 24))
                    .foregroundColor(Color.purp)
            }
        }
        .buttonStyle(.plain)
    }

    private func reorderDragGesture(
        for source: MediaSource,
        at index: Int,
        cols: Int,
        sidePad: CGFloat,
        geometrySize: CGSize
    ) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("mediaSourceGrid"))
            .onChanged { drag in
                self.handleDragChanged(drag, source: source, index: index, cols: cols, sidePad: sidePad, geometrySize: geometrySize)
            }
            .onEnded { _ in
                self.handleDragEnded(cols: cols)
            }
    }

    private func handleDragChanged(
        _ drag: DragGesture.Value,
        source: MediaSource,
        index: Int,
        cols: Int,
        sidePad: CGFloat,
        geometrySize: CGSize
    ) {
        if self.draggingID == nil, self.holdTimer == nil, !self.isReturningToSlot {
            let timer = DispatchWorkItem {
                withAnimation(.easeInOut(duration: 0.15)) {
                    self.draggingID = source.persistentModelID
                    self.dragPosition = Layout.positionForIndex(index, cols: cols)
                }
                self.onDragStateChanged?(true)
            }
            self.holdTimer = timer
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: timer)
        }

        guard self.draggingID != nil, !self.isReturningToSlot else { return }

        let rawPos = CGPoint(
            x: drag.location.x - sidePad,
            y: drag.location.y - sidePad
        )
        self.dragPosition = self.clampedPosition(rawPos, gridSize: geometrySize, sidePad: sidePad)

        if let currentIdx = self.currentDragIndex(),
           let targetIndex = self.indexForPosition(self.dragPosition, cols: cols, totalCount: self.sources.count),
           targetIndex != currentIdx
        {
            self.onReorder?(currentIdx, targetIndex)
        }
    }

    private func handleDragEnded(cols: Int) {
        self.holdTimer?.cancel()
        self.holdTimer = nil

        if let idx = self.currentDragIndex() {
            let targetPos = Layout.positionForIndex(idx, cols: cols)
            self.isReturningToSlot = true
            withAnimation(.easeInOut(duration: 0.2)) {
                self.dragPosition = targetPos
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.easeInOut(duration: 0.15)) {
                    self.draggingID = nil
                }
                self.isReturningToSlot = false
                self.onDragStateChanged?(false)
            }
        } else {
            withAnimation(.easeInOut(duration: 0.15)) {
                self.draggingID = nil
            }
            self.isReturningToSlot = false
            self.onDragStateChanged?(false)
        }
    }

    private func currentDragIndex() -> Int? {
        guard let id = self.draggingID else { return nil }
        return self.sources.firstIndex(where: { $0.persistentModelID == id })
    }

    private func indexForPosition(_ point: CGPoint, cols: Int, totalCount: Int) -> Int? {
        let cellSize = Layout.iconSize + Layout.gridSpacing
        let col = Int(point.x / cellSize)
        let row = Int(point.y / cellSize)
        let clampedCol = max(0, min(col, cols - 1))
        let clampedRow = max(0, row)
        let index = clampedRow * cols + clampedCol
        guard index >= 0, index < totalCount else { return nil }

        let targetCenter = Layout.positionForIndex(index, cols: cols)
        let dx = point.x - targetCenter.x
        let dy = point.y - targetCenter.y
        let distance = sqrt(dx * dx + dy * dy)
        let threshold = Layout.iconSize * 0.6
        guard distance < threshold else { return nil }

        return index
    }

    private func clampedPosition(_ point: CGPoint, gridSize: CGSize, sidePad: CGFloat) -> CGPoint {
        let halfIcon = Layout.iconSize / 2
        let minX = -sidePad + halfIcon
        let maxX = gridSize.width - sidePad - halfIcon
        let minY = -sidePad + halfIcon
        let maxY = gridSize.height - sidePad - halfIcon
        return CGPoint(
            x: min(max(point.x, minX), maxX),
            y: min(max(point.y, minY), maxY)
        )
    }
}

private extension View {
    @ViewBuilder
    func applyIf<Modified: View>(_ condition: Bool, transform: (Self) -> Modified) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
