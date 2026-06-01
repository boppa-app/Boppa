import SwiftUI

struct AddMediaSourceView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = AddMediaSourceViewModel()
    @State private var showingEditAlert = false
    @State private var isConfigProviderEditable = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Media Source URL") {
                    TextField("freesound.org", text: self.$viewModel.mediaSourceUrl)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .disabled(self.viewModel.isLoading)
                        .tint(Color.purp)
                        .accessibilityLabel("Media Source URL")
                        .accessibilityHint("Enter the URL of the media source")
                }
                Section("Config Provider URL") {
                    TextField(self.viewModel.configProviderUrl, text: self.$viewModel.configProviderUrl)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .disabled(self.viewModel.isLoading)
                        .foregroundColor(self.isConfigProviderEditable ? Color.white : Color.purp)
                        .overlay {
                            if !self.isConfigProviderEditable {
                                Color.clear
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        self.showingEditAlert = true
                                    }
                            }
                        }
                        .tint(Color.purp)
                        .accessibilityLabel("Config Provider URL")
                        .accessibilityHint(self.isConfigProviderEditable ? "Enter a custom config provider URL" : "Tap to edit the config provider URL")
                }
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(Color.red)
                        .font(.callout)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
            .scrollDisabled(true)
            .navigationTitle("Add Media Source")
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                self.cancelToolbarItem
                self.addToolbarItem
            }
            .alert("Edit Config Provider URL?", isPresented: self.$showingEditAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Edit") {
                    self.isConfigProviderEditable = true
                }
            } message: {
                Text("Are you sure you want to change the default config provider URL? Only use trusted config provided URLs.")
            }
        }
    }

    @ToolbarContentBuilder
    private var cancelToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(action: { self.dismiss() }) {
                Image(systemName: "xmark").font(.title3).foregroundColor(Color.red)
            }
            .disabled(self.viewModel.isLoading)
            .accessibilityLabel("Cancel")
            .accessibilityHint("Dismiss without adding a media source")
        }
        .sharedBackgroundVisibilityIfAvailable(.hidden)
    }

    @ToolbarContentBuilder
    private var addToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            if self.viewModel.isLoading {
                ProgressView()
                    .tint(.purp)
                    .accessibilityLabel("Adding media source")
            } else {
                Button(action: { self.addMediaSource() }) {
                    Image(systemName: "checkmark").font(.title3)
                        .foregroundColor(self.viewModel.isAddDisabled ? Color(.systemGray) : Color.purp)
                }
                .disabled(self.viewModel.isAddDisabled)
                .accessibilityLabel("Add Media Source")
                .accessibilityHint("Confirm and add the media source")
            }
        }
        .sharedBackgroundVisibilityIfAvailable(.hidden)
    }

    private func addMediaSource() {
        Task {
            let success = await viewModel.addMediaSource()
            if success {
                self.dismiss()
            }
        }
    }
}
