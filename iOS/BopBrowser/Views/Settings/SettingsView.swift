import SwiftData
import SwiftUI

struct SettingsView: View {
    @Binding var selectedTab: Int
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MediaSource.order) private var mediaSources: [MediaSource]
    @State private var showingAddSheet = false
    @State private var isClearingData = false
    @State private var showDataCleared = false
    @State private var showClearConfirmation = false
    @State private var isEditing = false
    @State private var selectedSource: MediaSource?

    private let iconSize: CGFloat = 64
    private let gridSpacing: CGFloat = 24
    private let minSidePadding: CGFloat = 16

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if self.isEditing {
                        self.editingList
                    } else {
                        self.mediaSourcesGrid
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .listRowBackground(Color(.systemGray6))
                    }
                } header: {
                    HStack {
                        Text("Media Sources").font(.body)
                        Spacer()
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                self.isEditing.toggle()
                            }
                        } label: {
                            Text(self.isEditing ? "Done" : "Edit")
                                .font(.body)
                                .foregroundColor(Color.purp)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section("Web Data") {
                    Button {
                        self.showClearConfirmation = true
                    } label: {
                        HStack {
                            Label("Clear All Web Data", systemImage: "trash")
                                .foregroundColor(.red)
                            if self.isClearingData {
                                Spacer()
                                ProgressView()
                                    .tint(Color.purp)
                            }
                        }
                    }
                    .disabled(self.isClearingData)
                }
            }
            .environment(\.editMode, self.isEditing ? .constant(.active) : .constant(.inactive))
            .navigationTitle("Settings")
            .onChange(of: self.selectedTab) { _, newTab in
                if newTab != 3 {
                    self.isEditing = false
                }
            }
            .sheet(isPresented: self.$showingAddSheet) {
                AddMediaSourceView()
            }
            .alert("Clear All Web Data?", isPresented: self.$showClearConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) {
                    self.isClearingData = true
                    WebDataStore.shared.clearAllData {
                        self.isClearingData = false
                        self.showDataCleared = true
                    }
                }
            } message: {
                Text("This will delete all cookies, cache, local storage, and session data. You will be logged out of all media sources.")
            }
            .alert("Web Data Cleared", isPresented: self.$showDataCleared) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("All web data has been cleared.")
            }
        }
    }

    private func columnsForWidth(_ width: CGFloat) -> Int {
        guard width > 0 else { return 1 }
        let available = width - 2 * self.minSidePadding
        if available < self.iconSize { return 1 }
        return max(1, Int((available + self.gridSpacing) / (self.iconSize + self.gridSpacing)))
    }

    @State private var computedGridHeight: CGFloat = 0

    private var mediaSourcesGrid: some View {
        GeometryReader { geometry in
            let cols = self.columnsForWidth(geometry.size.width)
            let totalIconsWidth = CGFloat(cols) * self.iconSize + CGFloat(cols - 1) * self.gridSpacing
            let sidePadding = (geometry.size.width - totalIconsWidth) / 2
            let rows = self.mediaSources.chunked(into: cols)

            VStack(alignment: .leading, spacing: self.gridSpacing) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: self.gridSpacing) {
                        ForEach(row) { source in
                            Button {
                                self.selectedSource = source
                            } label: {
                                MediaSourceIcon(source: source)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, sidePadding)
            .padding(.vertical, sidePadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onAppear {
                self.updateGridHeight(width: geometry.size.width)
            }
            .onChange(of: self.mediaSources.count) {
                self.updateGridHeight(width: geometry.size.width)
            }
            .onChange(of: geometry.size.width) { _, newWidth in
                self.updateGridHeight(width: newWidth)
            }
        }
        .frame(height: self.computedGridHeight)
        .navigationDestination(item: self.$selectedSource) { source in
            MediaSourceDetailView(viewModel: MediaSourceDetailViewModel(source: source, modelContext: self.modelContext))
        }
    }

    private func updateGridHeight(width: CGFloat) {
        let cols = self.columnsForWidth(width)
        let totalIconsWidth = CGFloat(cols) * self.iconSize + CGFloat(cols - 1) * self.gridSpacing
        let sidePadding = (width - totalIconsWidth) / 2
        let rowCount = ceil(Double(self.mediaSources.count) / Double(cols))
        let contentHeight = CGFloat(rowCount) * self.iconSize + CGFloat(max(rowCount - 1, 0)) * self.gridSpacing
        self.computedGridHeight = contentHeight + 2 * sidePadding
    }

    @ViewBuilder
    private var editingList: some View {
        ForEach(self.mediaSources) { source in
            MediaSourceIcon(source: source)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        }
        .onMove(perform: self.moveMediaSources)
        .onDelete(perform: self.deleteMediaSources)

        Button {
            self.showingAddSheet = true
        } label: {
            Label("Add Media Source", systemImage: "plus").foregroundColor(Color.purp)
        }
    }

    private func moveMediaSources(from source: IndexSet, to destination: Int) {
        var reordered = self.mediaSources
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, mediaSource) in reordered.enumerated() {
            mediaSource.order = index
        }
        try? self.modelContext.save()
    }

    private func deleteMediaSources(at offsets: IndexSet) {
        let deletedNames = offsets.map { self.mediaSources[$0].name }
        for index in offsets {
            let mediaSource = self.mediaSources[index]
            self.modelContext.delete(mediaSource)
        }
        try? self.modelContext.save()
        NotificationCenter.default.post(name: .mediaSourceRemoved, object: nil, userInfo: ["names": deletedNames])
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: self.count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, self.count)])
        }
    }
}

#Preview {
    SettingsView(selectedTab: .constant(3))
        .modelContainer(for: MediaSource.self, inMemory: true)
}
