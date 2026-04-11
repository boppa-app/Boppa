import SwiftUI

struct TrackActionsSheet: View {
    let track: Track
    let source: MediaSource
    var onArtistSelected: ((Artist) -> Void)?
    var onAlbumSelected: ((Album) -> Void)?

    @Environment(\.dismiss) private var dismiss

    private var artistEntries: [(name: String, artist: Artist)] {
        self.track.artists.map { (name: $0.key, artist: $0.value) }
    }

    private var albumEntries: [(name: String, album: Album)] {
        self.track.albums.map { (name: $0.key, album: $0.value) }
    }

    private var albumIcon: String {
        if #available(iOS 26.0, *) {
            return "music.note.square.stack.fill"
        } else {
            return "square.stack.fill"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            self.header
                .padding(.top, 20)
                .padding(.bottom, 12)

            List {
                ForEach(Array(self.artistEntries.enumerated()), id: \.offset) { _, entry in
                    if self.source.config.data?.getArtist != nil {
                        Button {
                            self.dismiss()
                            self.onArtistSelected?(entry.artist)
                        } label: {
                            self.rowLabel(
                                name: entry.name,
                                icon: "person.fill"
                            )
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color(.systemGray6))
                        .listRowInsets(EdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20))
                        .listRowSeparator(.hidden)
                    }
                }

                ForEach(Array(self.albumEntries.enumerated()), id: \.offset) { _, entry in
                    if self.source.config.data?.getAlbum != nil {
                        Button {
                            self.dismiss()
                            self.onAlbumSelected?(entry.album)
                        } label: {
                            self.rowLabel(
                                name: entry.name,
                                icon: self.albumIcon
                            )
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color(.systemGray6))
                        .listRowInsets(EdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20))
                        .listRowSeparator(.hidden)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .background(Color(.systemGray6))
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                ArtworkView(url: self.track.artworkUrl, placeholder: "music.note", size: 56)
                VStack(alignment: .leading, spacing: 4) {
                    MarqueeText(
                        self.track.title,
                        font: .title3,
                        fontWeight: .semibold
                    )
                    if let subtitle = self.track.subtitle {
                        MarqueeText(
                            subtitle,
                            font: .subheadline,
                            foregroundColor: Color(.systemGray)
                        )
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 28)

            Rectangle()
                .fill(Color(.systemGray5))
                .frame(height: 2)
                .padding(.horizontal, 16)
        }
    }

    private func rowLabel(name: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.purp)
                .frame(width: 24)
            (
                Text("Go to ")
                    .italic()
                    .foregroundColor(.white)
                    + Text(name)
                    .bold()
                    .foregroundColor(.purp)
            )
            .font(.body)
            .lineLimit(1)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.purp)
        }
        .contentShape(Rectangle())
    }
}
