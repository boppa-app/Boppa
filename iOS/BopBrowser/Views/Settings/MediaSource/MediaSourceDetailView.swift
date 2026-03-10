import SwiftUI

struct MediaSourceDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State var viewModel: MediaSourceDetailViewModel

    var body: some View {
        List {
            Section("Details") {
                LabeledContent("Name", value: self.viewModel.source.name)
                LabeledContent("URL", value: self.viewModel.source.url)
            }

            if let loginURL = self.viewModel.loginURL {
                Section("Authentication") {
                    if self.viewModel.isCheckingLogin {
                        HStack {
                            ProgressView()
                                .tint(Color.white)
                            Text("Checking Login Status…")
                                .foregroundColor(.white)
                                .padding(.leading, 8)
                        }
                    } else if self.viewModel.isLoggedIn {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Logged In")
                                .foregroundColor(.green)
                        }
                    } else {
                        Button {
                            self.viewModel.showingLogin = true
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
        }
        .navigationTitle(self.viewModel.source.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            self.backToolbarItem
        }
        .onAppear {
            self.viewModel.checkLoginStatus()
        }
        .sheet(isPresented: self.$viewModel.showingLogin) {
            if let loginURL = self.viewModel.loginURL {
                LoginWebView(viewModel: LoginWebViewModel(
                    url: loginURL,
                    customUserAgent: self.viewModel.source.config.customUserAgent,
                    requiredCookies: self.viewModel.source.config.login?.cookies ?? [],
                    cookieDomain: URL(string: self.viewModel.source.config.url)?.host,
                    mediaSourceName: self.viewModel.source.name
                ))
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
