import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MediaSource.createdAt) private var mediaSources: [MediaSource]
    @State private var showingAddSheet = false

    var body: some View {
        NavigationStack {
            List {
                Section("Media Sources") {
                    ForEach(mediaSources) { source in
                        MediaSourceRow(source: source)
                    }
                    .onDelete(perform: deleteMediaSources)

                    Button {
                        showingAddSheet = true
                    } label: {
                        Label("Add Media Source", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black, for: .navigationBar)
            .sheet(isPresented: $showingAddSheet) {
                AddMediaSourceView()
            }
        }
    }

    private func deleteMediaSources(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(mediaSources[index])
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: MediaSource.self, inMemory: true)
}
