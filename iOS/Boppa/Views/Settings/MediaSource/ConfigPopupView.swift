import SwiftUI

struct ConfigPopupView: View {
    @Environment(\.dismiss) private var dismiss
    let popups: [String: PopupConfig]

    var body: some View {
        VStack(spacing: 0) {
            DetailHeaderView(
                title: "Popup",
                onBack: { self.dismiss() }
            )

            ScrollFadeView {
                List {
                    ForEach(Array(self.popups.sorted(by: { $0.key < $1.key })), id: \.key) { (id: String, popup: PopupConfig) in
                        Section(popup.title) {
                            LabeledContent("ID", value: id)
                            LabeledContent("URL", value: popup.url)

                            if !popup.userScripts.isEmpty {
                                ForEach(Array(popup.userScripts.enumerated()), id: \.offset) { (_: Int, script: Script) in
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
}
