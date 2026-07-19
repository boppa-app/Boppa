import SwiftUI
import UniformTypeIdentifiers

struct AddMediaSourceView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: AddMediaSourceViewModel
    @State private var isFileImporterPresented = false
    private let autoSubmit: Bool

    private static let configContentTypes: [UTType] = [
        UTType(filenameExtension: "yaml"),
        UTType(filenameExtension: "yml"),
        .item,
    ].compactMap { $0 }

    init(initialConfigUrl: String = "") {
        self._viewModel = State(initialValue: AddMediaSourceViewModel(configUrl: initialConfigUrl))
        self.autoSubmit = !initialConfigUrl.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                if let fileName = self.viewModel.selectedFileName {
                    Section("File Selected") {
                        HStack {
                            Image(systemName: "doc")
                                .foregroundColor(Color.purp)
                            Text(fileName)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    self.viewModel.clearSelectedFile()
                                }
                            }) {
                                Image(systemName: "xmark")
                                    .foregroundColor(.red)
                            }
                            .disabled(self.viewModel.isLoading)
                            .accessibilityLabel("Remove Selected File")
                            .accessibilityHint("Detach the selected config file")
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                } else {
                    Section("Option 1: From URL") {
                        TextField("cdn.boppa.app/media-source-config/iOS/internet-archive.yaml", text: self.$viewModel.configUrl)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .disabled(self.viewModel.isLoading)
                            .tint(Color.purp)
                            .accessibilityLabel("Media Source Config URL")
                            .accessibilityHint("Enter the URL of the media source config")
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))

                    Section("Option 2: From Files") {
                        Button(action: { self.isFileImporterPresented = true }) {
                            HStack(spacing: 8) {
                                Image(systemName: "doc.badge.plus")
                                    .foregroundColor(.purp)
                                Text("Choose File")
                                    .foregroundColor(.purp)
                            }
                        }
                        .disabled(self.viewModel.isLoading)
                        .accessibilityLabel("Choose Media Source Config File")
                        .accessibilityHint("Pick a local config file to import")
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                if let errorMessage = viewModel.errorMessage {
                    ErrorMessageView(message: errorMessage)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                self.helpLinksView
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
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
        .fileImporter(
            isPresented: self.$isFileImporterPresented,
            allowedContentTypes: Self.configContentTypes
        ) { result in
            switch result {
            case let .success(url):
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.viewModel.selectedFileURL = url
                }
                self.viewModel.errorMessage = nil
            case let .failure(error):
                self.viewModel.errorMessage = error.localizedDescription
            }
        }
    }

    private var helpLinksView: some View {
        VStack(spacing: 36) {
            Text(self.redditAttributedString)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 6) {
                Text("How do I make a media source config?")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Link("boppa.app/docs", destination: URL(string: "https://boppa.app/docs")!)
                    .font(.subheadline)
                    .foregroundColor(Color.purp)
                    .accessibilityHint("Opens the media source config documentation in your browser")
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var redditAttributedString: AttributedString {
        var text = AttributedString("Check out media source configs built by the community on ")
        var link = AttributedString("/r/BoppaApp")
        link.link = URL(string: "https://www.reddit.com/r/BoppaApp/")
        link.foregroundColor = Color.purp
        text += link
        text += AttributedString(".")
        return text
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
                SpinnerView(tint: .purp, lineWidth: 3)
                    .frame(width: 20, height: 20)
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
