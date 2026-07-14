import SwiftUI

struct SettingsView: View {
    @Binding var selectedTab: Int
    var navigationResetId: Int = 0
    @Binding var isAtNavigationRoot: Bool
    @State private var viewModel = SettingsViewModel()
    @State private var navigationPath = NavigationPath()
    @State private var isClearingData = false
    @State private var showDataCleared = false
    @State private var showClearConfirmation = false
    @State private var isEditing = false
    @State private var isEditMode = false

    var body: some View {
        NavigationStack(path: self.$navigationPath) {
            List {
                self.mediaSourcesSection
                self.webDataSection
            }
            .environment(\.editMode, self.isEditMode ? .constant(.active) : .constant(.inactive))
            .navigationTitle("Settings")
            .navigationDestination(for: MediaSource.self) { mediaSource in
                MediaSourceDetailView(viewModel: MediaSourceDetailViewModel(mediaSource: mediaSource))
            }
            .onAppear {
                self.viewModel.loadSources()
                self.isAtNavigationRoot = self.navigationPath.isEmpty
            }
            .onDisappear {
                self.isAtNavigationRoot = false
            }
            .onReceive(NotificationCenter.default.publisher(for: .mediaSourceAdded)) { _ in
                self.viewModel.loadSources()
            }
            .onReceive(NotificationCenter.default.publisher(for: .mediaSourceRemoved)) { _ in
                self.viewModel.loadSources()
            }
            .onReceive(NotificationCenter.default.publisher(for: .mediaSourceEnabled)) { _ in
                self.viewModel.loadSources()
            }
            .onReceive(NotificationCenter.default.publisher(for: .mediaSourceDisabled)) { _ in
                self.viewModel.loadSources()
            }
            .onChange(of: self.navigationPath.count) { _, newCount in
                self.isAtNavigationRoot = (newCount == 0)
            }
            .onChange(of: self.navigationResetId) { _, _ in
                self.navigationPath = NavigationPath()
            }
            .onChange(of: self.selectedTab) { _, newTab in
                if newTab != 2 {
                    self.isEditing = false
                    self.isEditMode = false
                }
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

    private var mediaSourcesSection: some View {
        Section {
            ForEach(self.viewModel.mediaSources) { mediaSource in
                if self.isEditing {
                    self.mediaSourceRow(mediaSource)
                        .id(mediaSource.id)
                        .listRowSeparator(.hidden)
                } else {
                    NavigationLink(value: mediaSource) {
                        self.mediaSourceRow(mediaSource)
                    }
                    .id(mediaSource.id)
                }
            }
            .onMove(perform: self.viewModel.moveMediaSources)
            .onDelete(perform: self.deleteMediaSources)

            if self.isEditing {
                Button {
                    DeepLinkAddMediaSourceRequest.shared.submit(configUrl: "")
                } label: {
                    Label("Add Media Source", systemImage: "plus").foregroundColor(Color.purp)
                }
            }
        } header: {
            HStack {
                Text("Media Sources")
                    .font(.body)
                Spacer()
                Button {
                    self.isEditing.toggle()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.isEditMode = self.isEditing
                    }
                } label: {
                    Text(self.isEditing ? "Done" : "Edit")
                        .font(.body)
                        .foregroundColor(Color.purp)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(self.isEditing ? "Done Editing" : "Edit Media Sources")
                .accessibilityHint(self.isEditing ? "Exit editing mode" : "Manage and reorder media sources")
            }
        }
    }

    private var webDataSection: some View {
        Section {
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
                            .accessibilityLabel("Clearing data")
                    }
                }
            }
            .disabled(self.isClearingData)
            .accessibilityLabel("Clear All Web Data")
            .accessibilityHint("Delete all cookies, cache, local storage, and session data")
        } header: {
            Text("Web Data")
                .font(.body)
        }
    }

    private func mediaSourceRow(_ mediaSource: MediaSource) -> some View {
        HStack(spacing: 12) {
            if let iconSvg = mediaSource.config.iconSvg {
                SVGImageView(svgString: iconSvg, size: 24)
                    .frame(width: 32, height: 32)
                    .opacity(mediaSource.isEnabled ? 1.0 : 0.5)
            } else {
                Image(systemName: "music.note")
                    .font(.title3)
                    .foregroundColor(mediaSource.isEnabled ? Color.purp : Color(.systemGray2))
                    .frame(width: 32, height: 32)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(mediaSource.config.name)
                    .font(.body)
                    .foregroundColor(mediaSource.isEnabled ? .primary : Color(.systemGray2))
                Text(mediaSource.config.url)
                    .font(.caption)
                    .foregroundColor(mediaSource.isEnabled ? .secondary : Color(.systemGray3))
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }

    private func deleteMediaSources(at offsets: IndexSet) {
        self.viewModel.deleteMediaSource(at: offsets)
    }
}

#Preview {
    SettingsView(selectedTab: .constant(2), isAtNavigationRoot: .constant(true))
}
