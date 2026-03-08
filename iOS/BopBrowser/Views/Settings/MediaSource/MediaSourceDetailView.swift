import SwiftUI

struct MediaSourceDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let source: MediaSource
    @State private var showingLogin = false

    private var loginURL: URL? {
        guard let urlString = self.source.config.login?.url else { return nil }
        return URL(string: urlString)
    }

    var body: some View {
        List {
            Section("Details") {
                LabeledContent("Name", value: self.source.name)
                LabeledContent("URL", value: self.source.url)
            }

            if let loginURL {
                Section("Authentication") {
                    Button {
                        self.showingLogin = true
                    } label: {
                        HStack {
                            Image(systemName: "person.crop.circle")
                                .foregroundColor(Color.purp)
                            Text("Login")
                                .foregroundColor(Color.purp)
                        }
                    }
                }
            }
        }
        .navigationTitle(self.source.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            self.backToolbarItem
        }
        .sheet(isPresented: self.$showingLogin) {
            if let loginURL {
                LoginWebView(url: loginURL)
            }
        }
    }

    @ToolbarContentBuilder
    private var backToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button(action: { self.dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .foregroundColor(Color.purp)
            }
        }
        .sharedBackgroundVisibilityIfAvailable(.hidden)
    }
}
