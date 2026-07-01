import SwiftUI

private let relativeTimeFormatter: RelativeDateTimeFormatter = {
    let f = RelativeDateTimeFormatter()
    f.unitsStyle = .full
    return f
}()

struct MediaSourceDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State var viewModel: MediaSourceDetailViewModel

    var body: some View {
        VStack(spacing: 0) {
            DetailHeaderView(
                title: self.viewModel.mediaSource.config.name,
                onBack: { self.dismiss() }
            )

            ScrollFadeView {
                List {
                    Section("Details") {
                        LabeledContent("Name", value: self.viewModel.mediaSource.name)
                        LabeledContent("URL", value: self.viewModel.mediaSource.url)
                    }

                    Section("Options") {
                        HStack {
                            Text("Enabled")
                                .foregroundColor(self.viewModel.isContextGathered ? .white : .secondary)
                            Spacer()
                            SolidToggle(isOn: self.$viewModel.isSourceEnabled)
                                .fixedSize()
                                .disabled(!self.viewModel.isContextGathered)
                                .accessibilityLabel("Enable Media Source")
                                .accessibilityValue(self.viewModel.isSourceEnabled ? "On" : "Off")
                                .accessibilityHint(self.viewModel.isContextGathered ? "Toggle to enable or disable this media source" : "Available after context is gathered")
                                .accessibilityAddTraits(.isButton)
                        }
                    }

                    if let contexts = self.viewModel.mediaSource.config.context, !contexts.isEmpty,
                       let gatheredDate = self.viewModel.mediaSource.contextLastGatheredDate
                    {
                        Section("Status") {
                            LabeledContent {
                                Text(relativeTimeFormatter.localizedString(for: gatheredDate, relativeTo: Date()))
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            } label: {
                                Text("Context Gathered")
                            }
                        }
                    }

                    Section("Config") {
                        if let contexts = self.viewModel.mediaSource.config.context, !contexts.isEmpty {
                            NavigationLink(destination: ConfigContextView(contexts: contexts)) {
                                HStack(spacing: 8) {
                                    Image(systemName: "safari")
                                        .foregroundColor(.purp)
                                    Text("Context")
                                        .foregroundColor(.white)
                                }
                            }
                        }

                        NavigationLink(destination: ConfigDataView(data: self.viewModel.mediaSource.config.data)) {
                            HStack(spacing: 8) {
                                Image(systemName: "doc")
                                    .foregroundColor(.purp)
                                Text("Data")
                                    .foregroundColor(.white)
                            }
                        }

                        NavigationLink(destination: ConfigPlaybackView(playback: self.viewModel.mediaSource.config.playback)) {
                            HStack(spacing: 8) {
                                Image(systemName: "play")
                                    .foregroundColor(.purp)
                                Text("Playback")
                                    .foregroundColor(.white)
                            }
                        }

                        if let popups = self.viewModel.mediaSource.config.popup, !popups.isEmpty {
                            NavigationLink(destination: ConfigPopupView(popups: popups)) {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.bubble")
                                        .foregroundColor(.purp)
                                    Text("Popup")
                                        .foregroundColor(.white)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .enableSwipeBack()
    }
}
