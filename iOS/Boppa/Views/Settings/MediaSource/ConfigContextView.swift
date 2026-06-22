import SwiftUI

struct ConfigContextView: View {
    @Environment(\.dismiss) private var dismiss
    let contexts: [ContextConfig]

    var body: some View {
        VStack(spacing: 0) {
            DetailHeaderView(
                title: "Context",
                onBack: { self.dismiss() }
            )

            ScrollFadeView {
                List {
                    ForEach(Array(self.contexts.enumerated()), id: \.offset) { (_: Int, context: ContextConfig) in
                        Section(context.title) {
                            LabeledContent("URL", value: context.url)
                            LabeledContent("Interval", value: Self.formatInterval(context.intervalSeconds))

                            if !context.userScripts.isEmpty {
                                ForEach(Array(context.userScripts.enumerated()), id: \.offset) { (_: Int, script: Script) in
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
            }
        }
        .navigationBarHidden(true)
        .enableSwipeBack()
    }

    private static func formatInterval(_ seconds: Int) -> String {
        if seconds % 86400 == 0 {
            let days = seconds / 86400
            return days == 1 ? "1 day" : "\(days) days"
        } else if seconds % 3600 == 0 {
            let hours = seconds / 3600
            return hours == 1 ? "1 hour" : "\(hours) hours"
        } else if seconds % 60 == 0 {
            let minutes = seconds / 60
            return minutes == 1 ? "1 minute" : "\(minutes) minutes"
        } else {
            return seconds == 1 ? "1 second" : "\(seconds) seconds"
        }
    }
}
