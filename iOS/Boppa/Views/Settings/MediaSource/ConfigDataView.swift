import SwiftUI

struct ConfigDataView: View {
    @Environment(\.dismiss) private var dismiss
    let data: DataScripts

    var body: some View {
        VStack(spacing: 0) {
            DetailHeaderView(
                title: "Data",
                onBack: { self.dismiss() }
            )

            ScrollFadeView {
                List {
                    if !self.searchItems.isEmpty {
                        Section("Search") {
                            ForEach(self.searchItems, id: \.label) { item in
                                NavigationLink(destination: CodeView(
                                    title: item.label,
                                    code: item.code
                                )) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "doc.text")
                                            .foregroundColor(.purp)
                                        Text(item.label)
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                        }
                    }

                    if !self.getItems.isEmpty {
                        Section("Get") {
                            ForEach(self.getItems, id: \.label) { item in
                                NavigationLink(destination: CodeView(
                                    title: item.label,
                                    code: item.code
                                )) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "doc.text")
                                            .foregroundColor(.purp)
                                        Text(item.label)
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                        }
                    }

                    if !self.listItems.isEmpty {
                        Section("List") {
                            ForEach(self.listItems, id: \.label) { item in
                                NavigationLink(destination: CodeView(
                                    title: item.label,
                                    code: item.code
                                )) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "doc.text")
                                            .foregroundColor(.purp)
                                        Text(item.label)
                                            .foregroundColor(.white)
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

    private var searchItems: [(label: String, code: String)] {
        guard let search = self.data.search else { return [] }
        var items: [(String, String)] = []
        if let v = search.songs { items.append(("Songs", v)) }
        if let v = search.artists { items.append(("Artists", v)) }
        if let v = search.albums { items.append(("Albums", v)) }
        if let v = search.playlists { items.append(("Playlists", v)) }
        if let v = search.videos { items.append(("Videos", v)) }
        return items
    }

    private var getItems: [(label: String, code: String)] {
        guard let get = self.data.get else { return [] }
        var items: [(String, String)] = []
        if let v = get.song { items.append(("Song", v)) }
        if let v = get.artist { items.append(("Artist", v)) }
        if let v = get.album { items.append(("Album", v)) }
        if let v = get.playlist { items.append(("Playlist", v)) }
        if let v = get.video { items.append(("Video", v)) }
        return items
    }

    private var listItems: [(label: String, code: String)] {
        guard let list = self.data.list else { return [] }
        var items: [(String, String)] = []
        if let v = list.album { items.append(("Album", v)) }
        if let v = list.playlist { items.append(("Playlist", v)) }
        if let v = list.artistSongs { items.append(("Artist Songs", v)) }
        if let v = list.artistVideos { items.append(("Artist Videos", v)) }
        if let v = list.artistAlbums { items.append(("Artist Albums", v)) }
        if let v = list.artistPlaylists { items.append(("Artist Playlists", v)) }
        return items
    }
}
