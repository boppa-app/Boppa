import SwiftUI

struct AddMediaSourceView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = AddMediaSourceViewModel()
    @State private var showingEditAlert = false
    @State private var isConfigProviderEditable = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Media Source URL") {
                    TextField("freesound.org", text: $viewModel.mediaSourceUrl)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .disabled(viewModel.isLoading)
                }
                Section("Config Provider URL") {
                    TextField(viewModel.configProviderUrl, text: $viewModel.configProviderUrl)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .disabled(viewModel.isLoading)
                        .foregroundColor(isConfigProviderEditable ? Color.white : Color.purp)
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
        ToolbarItem(placement: .cancellationAction) {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark").font(.title3).foregroundColor(Color.red)
            }
            .disabled(viewModel.isLoading)
        }
        .sharedBackgroundVisibilityIfAvailable(.hidden)
    }

    @ToolbarContentBuilder
    private var addToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            if viewModel.isLoading {
                ProgressView()
                    .tint(.purp)
            } else {
                Button(action: { addMediaSource() }) {
                    Image(systemName: "checkmark").font(.title3)
                        .foregroundColor(viewModel.isAddDisabled ? Color(.systemGray) : Color.purp)
                }
                .disabled(viewModel.isAddDisabled)
            }
        }
        .sharedBackgroundVisibilityIfAvailable(.hidden)
    }

    private func addMediaSource() {
        Task {
            let success = await viewModel.addMediaSource(modelContext: modelContext)
            if success {
                dismiss()
            }
        }
    }
}
