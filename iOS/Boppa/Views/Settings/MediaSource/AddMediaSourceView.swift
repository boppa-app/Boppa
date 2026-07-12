import SwiftUI

struct AddMediaSourceView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: AddMediaSourceViewModel
    private let autoSubmit: Bool

    init(initialConfigUrl: String = "") {
        self._viewModel = State(initialValue: AddMediaSourceViewModel(configUrl: initialConfigUrl))
        self.autoSubmit = !initialConfigUrl.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Media Source Config URL") {
                    TextField("config.boppa.app/iOS/internet-archive.yaml", text: self.$viewModel.configUrl)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .disabled(self.viewModel.isLoading)
                        .tint(Color.purp)
                        .accessibilityLabel("Media Source Config URL")
                        .accessibilityHint("Enter the URL of the media source config")
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
        }
        .task {
            guard self.autoSubmit, !self.viewModel.isAddDisabled else { return }
            self.addMediaSource()
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
                    .accessibilityLabel(self.viewModel.isGatheringContext ? "Gathering context" : "Adding media source")
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
