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
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle("Add Media Source")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbar {
                cancelToolbarItem
                addToolbarItem
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

    @ToolbarContentBuilder
    private var cancelToolbarItem: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .cancellationAction) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark").font(.title3).foregroundColor(Color.red)
                }
            }
            .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .cancellationAction) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark").font(.title3).foregroundColor(Color.red)
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var addToolbarItem: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .confirmationAction) {
                Button(action: { addMediaSource() }) {
                    Image(systemName: "checkmark").font(.title3).foregroundColor(Color.green)
                }
                .disabled(mediaSourceUrl.isEmpty || configProviderUrl.isEmpty)
            }
            .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .confirmationAction) {
                Button(action: { addMediaSource() }) {
                    Image(systemName: "checkmark").font(.title3).foregroundColor(Color.green)
                }
                .disabled(mediaSourceUrl.isEmpty || configProviderUrl.isEmpty)
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
