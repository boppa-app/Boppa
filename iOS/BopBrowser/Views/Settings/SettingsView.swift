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

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(self.mediaSources) { source in
                        if self.isEditing {
                            MediaSourceRow(source: source)
                        } else {
                            NavigationLink(destination: MediaSourceDetailView(viewModel: MediaSourceDetailViewModel(source: source, modelContext: self.modelContext))) {
                                MediaSourceRow(source: source)
                            }
                        }
                    }
                    .onMove(perform: self.moveMediaSources)
                    .onDelete(perform: self.deleteMediaSources)

                    if self.isEditing {
                        Button {
                            self.showingAddSheet = true
                        } label: {
                            Label("Add Media Source", systemImage: "plus").foregroundColor(Color.purp)
                        }
                    }
                } header: {
                    HStack {
                        Text("Media Sources").font(.body)
                        Spacer()
                        Button {
                            self.isEditing.toggle()
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

#Preview {
    SettingsView(selectedTab: .constant(3))
        .modelContainer(for: MediaSource.self, inMemory: true)
}
