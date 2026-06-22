import SwiftUI

struct ConfigPlaybackView: View {
    @Environment(\.dismiss) private var dismiss
    let playback: PlaybackConfig

    var body: some View {
        VStack(spacing: 0) {
            DetailHeaderView(
                title: "Playback",
                onBack: { self.dismiss() }
            )

            List {
                if let url = self.playback.url {
                    Section("URL") {
                        Text(url)
                            .foregroundColor(.white)
                    }
                }

                if let html = self.playback.html {
                    Section("HTML") {
                        NavigationLink(destination: CodeView(
                            title: "HTML",
                            code: html
                        )) {
                            HStack(spacing: 8) {
                                Image(systemName: "doc.richtext")
                                    .foregroundColor(.purp)
                                Text("View HTML")
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }

                if !self.playback.userScripts.isEmpty {
                    Section("Scripts") {
                        ForEach(Array(self.playback.userScripts.enumerated()), id: \.offset) { (_: Int, script: Script) in
                            NavigationLink(destination: CodeView(
                                title: script.title,
                                code: script.content
                            )) {
                                HStack(spacing: 8) {
                                    Image(systemName: "scroll")
                                        .foregroundColor(.purp)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(script.title)
                                            .foregroundColor(.white)
                                        Text(
                                            script.injectionTime == .atDocumentStart
                                                ? "Runs At Document Start"
                                                : "Runs At Document End"
                                        )
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    }
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
