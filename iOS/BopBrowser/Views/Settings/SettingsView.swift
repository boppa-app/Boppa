import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var mediaSources: [MediaSource]
    @State private var showingAddSheet = false

    var body: some View {
        NavigationStack {
            List {
                Section("Media Sources") {
                    ForEach(self.mediaSources) { source in
                        NavigationLink(destination: MediaSourceDetailView(source: source)) {
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
            }
            .navigationTitle("Settings")
            .sheet(isPresented: self.$showingAddSheet) {
                AddMediaSourceView()
            }
        }
    }

    private func deleteMediaSources(at offsets: IndexSet) {
        for index in offsets {
            self.modelContext.delete(self.mediaSources[index])
        }
        try? self.modelContext.save()
        NotificationCenter.default.post(name: .mediaSourcesDidChange, object: nil)
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: MediaSource.self, inMemory: true)
}
