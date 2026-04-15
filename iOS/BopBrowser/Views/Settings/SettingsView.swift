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
    @State private var selectedMediaSource: MediaSource?
    @State private var computedGridHeight: CGFloat = 100
    @State private var showDeleteConfirmation = false
    @State private var pendingDeleteIndex: Int?
    @State private var isDraggingSource = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    self.mediaSourcesGrid
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowBackground(Color(.systemGray6))
                } header: {
                    HStack {
                        Text("Media Sources")
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
            .alert("Remove Media Source?", isPresented: self.$showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    self.pendingDeleteIndex = nil
                }
                Button("Remove", role: .destructive) {
                    if let index = self.pendingDeleteIndex {
                        self.deleteMediaSource(at: index)
                    }
                    self.pendingDeleteIndex = nil
                }
            } message: {
                Text("This media source will be removed. This action cannot be undone.")
            }
            .alert("Web Data Cleared", isPresented: self.$showDataCleared) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("All web data has been cleared.")
            }
        }
    }

    private var mediaSourcesGrid: some View {
        MediaSourceGridView(
            mediaSources: Array(self.mediaSources),
            isEditing: self.isEditing,
            onReorder: self.moveMediaSource,
            onAdd: { self.showingAddSheet = true },
            onDragStateChanged: { isDragging in
                self.isDraggingSource = isDragging
            }
        ) { mediaSource in
            Button {
                if !self.isEditing {
                    self.selectedMediaSource = mediaSource
                }
            } label: {
                MediaSourceIcon(
                    mediaSource: mediaSource,
                    onDelete: self.isEditing ? {
                        if let index = self.mediaSources.firstIndex(where: { $0.persistentModelID == mediaSource.persistentModelID }) {
                            self.confirmDeleteMediaSource(at: index)
                        }
                    } : nil,
                    showDeleteButton: !self.isDraggingSource
                )
            }
            .buttonStyle(.plain)
        }
        .background(
            GeometryReader { geometry in
                Color.clear.onAppear {
                    self.recomputeGridHeight(for: geometry.size.width)
                }
                .onChange(of: geometry.size.width) { _, newWidth in
                    self.recomputeGridHeight(for: newWidth)
                }
                .onChange(of: self.mediaSources.count) {
                    self.recomputeGridHeight(for: geometry.size.width)
                }
                .onChange(of: self.isEditing) {
                    self.recomputeGridHeight(for: geometry.size.width)
                }
            }
        )
        .frame(height: self.computedGridHeight)
        .navigationDestination(item: self.$selectedMediaSource) { mediaSource in
            MediaSourceDetailView(viewModel: MediaSourceDetailViewModel(mediaSource: mediaSource, modelContext: self.modelContext))
        }
    }

    private func moveMediaSource(from sourceIndex: Int, to destinationIndex: Int) {
        var reordered = Array(self.mediaSources)
        let item = reordered.remove(at: sourceIndex)
        reordered.insert(item, at: destinationIndex)
        for (index, mediaSource) in reordered.enumerated() {
            mediaSource.order = index
        }
        try? self.modelContext.save()
    }

    private func confirmDeleteMediaSource(at index: Int) {
        self.pendingDeleteIndex = index
        self.showDeleteConfirmation = true
    }

    private func deleteMediaSource(at index: Int) {
        let mediaSource = self.mediaSources[index]
        let deletedIds = [mediaSource.id]
        withAnimation(.easeInOut(duration: 0.55)) {
            self.modelContext.delete(mediaSource)
            try? self.modelContext.save()
        }
        NotificationCenter.default.post(name: .mediaSourceRemoved, object: nil, userInfo: ["ids": deletedIds])
    }

    private func recomputeGridHeight(for width: CGFloat) {
        self.computedGridHeight = MediaSourceGridLayout.gridHeight(
            for: width,
            mediaSourceCount: self.mediaSources.count,
            isEditing: self.isEditing
        )
    }
}

#Preview {
    SettingsView(selectedTab: .constant(3))
        .modelContainer(for: MediaSource.self, inMemory: true)
}
