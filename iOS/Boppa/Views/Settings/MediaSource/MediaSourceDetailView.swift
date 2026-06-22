import SwiftUI

struct MediaSourceDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State var viewModel: MediaSourceDetailViewModel

    var body: some View {
        VStack(spacing: 0) {
            DetailHeaderView(
                title: self.viewModel.mediaSource.config.name,
                onBack: { self.dismiss() }
            )

            List {
                Section("Details") {
                    LabeledContent("Name", value: self.viewModel.mediaSource.name)
                    LabeledContent("URL", value: self.viewModel.mediaSource.url)
                }

                Section("Options") {
                    HStack {
                        Text("Enabled")
                            .foregroundColor(.white)
                        Spacer()
                        SolidToggle(isOn: self.$viewModel.isSourceEnabled)
                            .fixedSize()
                            .accessibilityLabel("Enable Media Source")
                            .accessibilityValue(self.viewModel.isSourceEnabled ? "On" : "Off")
                            .accessibilityHint("Toggle to enable or disable this media source")
                            .accessibilityAddTraits(.isButton)
                    }
                }

                Section("Config") {
                    if let contexts = self.viewModel.mediaSource.config.context, !contexts.isEmpty {
                        NavigationLink(destination: ConfigContextView(contexts: contexts)) {
                            HStack(spacing: 8) {
                                Image(systemName: "globe")
                                    .foregroundColor(.purp)
                                Text("Context")
                                    .foregroundColor(.white)
                            }
                        }
                    }

                    NavigationLink(destination: ConfigDataView(data: self.viewModel.mediaSource.config.data)) {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.text")
                                .foregroundColor(.purp)
                            Text("Data")
                                .foregroundColor(.white)
                        }
                    }

                    NavigationLink(destination: ConfigPlaybackView(playback: self.viewModel.mediaSource.config.playback)) {
                        HStack(spacing: 8) {
                            Image(systemName: "play.circle")
                                .foregroundColor(.purp)
                            Text("Playback")
                                .foregroundColor(.white)
                        }
                    }
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
                            .accessibilityLabel("Login")
                            .accessibilityHint("Log in to this media source")
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .enableSwipeBack()
        .onAppear {
            self.viewModel.checkLoginStatus()
        }
        .sheet(isPresented: self.$viewModel.showingLogin) {
            if let loginURL = self.viewModel.loginURL {
                LoginWebView(viewModel: LoginWebViewModel(
                    url: loginURL,
                    customUserAgent: self.viewModel.mediaSource.config.customUserAgent,
                    requiredCookies: self.viewModel.mediaSource.config.login?.cookies ?? [],
                    cookieDomain: URL(string: self.viewModel.mediaSource.config.url)?.host,
                    mediaSourceId: self.viewModel.mediaSource.id
                ))
            }
        }
    }
}
