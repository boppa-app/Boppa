import SwiftUI

struct MediaSourceDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State var viewModel: MediaSourceDetailViewModel

    var body: some View {
        VStack(spacing: 0) {
            DetailHeaderView(
                title: self.viewModel.source.name,
                onBack: { self.dismiss() }
            )

            List {
                Section("Enabled") {
                    HStack {
                        SolidToggle(isOn: self.$viewModel.isSourceEnabled)
                            .fixedSize()
                        Spacer()
                    }
                }

                Section("Details") {
                    LabeledContent("Name", value: self.viewModel.source.name)
                    LabeledContent("URL", value: self.viewModel.source.url)
                }

                if let _ = self.viewModel.loginURL {
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
        }
        .navigationBarHidden(true)
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
}
