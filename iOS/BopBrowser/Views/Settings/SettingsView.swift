import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var mediaSources: [MediaSource]
    @State private var showingAddSheet = false
    @State private var isClearingData = false
    @State private var showDataCleared = false
    @State private var showClearConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                Section("Media Sources") {
                    ForEach(self.mediaSources) { source in
                        NavigationLink(destination: MediaSourceDetailView(viewModel: MediaSourceDetailViewModel(source: source))) {
                            MediaSourceRow(source: source)
                        }
                    }
                    .onDelete(perform: self.deleteMediaSources)

                    Button {
                        self.showingAddSheet = true
                    } label: {
                        Label("Add Media Source", systemImage: "plus").foregroundColor(Color.purp)
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

    private func deleteMediaSources(at offsets: IndexSet) {
        let removedNames = offsets.map { self.mediaSources[$0].name }
        for index in offsets {
            self.modelContext.delete(self.mediaSources[index])
        }
        try? self.modelContext.save()
        NotificationCenter.default.post(name: .mediaSourceRemoved, object: nil, userInfo: ["names": removedNames])
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: MediaSource.self, inMemory: true)
}
