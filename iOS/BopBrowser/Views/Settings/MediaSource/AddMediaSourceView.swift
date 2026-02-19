import SwiftData
import SwiftUI

struct AddMediaSourceView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var mediaSourceUrl = ""
    @State private var configProviderUrl = "bopbrowser.com"
    @State private var showingEditAlert = false
    @State private var isConfigProviderEditable = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Media Source URL") {
                    TextField("freesound.org", text: $mediaSourceUrl)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                }
                Section("Config Provider URL") {
                    TextField(configProviderUrl, text: $configProviderUrl)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .disabled(!isConfigProviderEditable)
                        .foregroundColor(isConfigProviderEditable ? Color.white : Color(.systemGray))
                        .overlay {
                            if !isConfigProviderEditable {
                                Color.clear
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        showingEditAlert = true
                                    }
                            }
                        }
                }
            }
            .navigationTitle("Add Media Source")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addMediaSource()
                    }
                    .disabled(mediaSourceUrl.isEmpty || configProviderUrl.isEmpty)
                }
            }
            .alert("Edit Config Provider URL?", isPresented: $showingEditAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Edit") {
                    isConfigProviderEditable = true
                }
            } message: {
                Text("Are you sure you want to change the default config provider URL? Only use trusted config provided URLs.")
            }
        }
    }

    private func addMediaSource() {
        let source = MediaSource(
            mediaSourceUrl: mediaSourceUrl,
            configProviderUrl: configProviderUrl
        )
        modelContext.insert(source)
        dismiss()
    }
}
