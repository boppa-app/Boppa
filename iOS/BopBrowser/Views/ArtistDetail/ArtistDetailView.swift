import SwiftUI

struct ArtistDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = ArtistDetailViewModel()

    let artist: Artist
    let source: MediaSource

    private let maxAlbums = 3
    private let maxSongs = 5
    private let maxVideos = 5
    private let maxPlaylists = 3

    var body: some View {
        VStack(spacing: 0) {
            DetailHeaderView(
                title: self.artist.name,
                onBack: { self.dismiss() }
            )
            self.content
        }
        .navigationBarHidden(true)
        .enableSwipeBack()
        .onAppear {
            self.viewModel.load(
                artist: self.artist,
                source: self.source
            )
        }
    }

    private var content: some View {
        Group {
            if let errorMessage = self.viewModel.errorMessage {
                self.errorView(message: errorMessage)
            } else if self.viewModel.detail == nil && self.viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let detail = self.viewModel.detail, detail.isEmpty {
                self.emptyState
            } else if let detail = self.viewModel.detail {
                self.detailList(detail)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func detailList(_ detail: ArtistDetail) -> some View {
        ScrollFadeView {
            List {
                ForEach(detail.sectionOrder, id: \.self) { section in
                    switch section {
                    case .albums:
                        if detail.albums != nil {
                            self.albumsSection(detail)
                        }
                    case .songs:
                        if detail.songs != nil {
                            self.songsSection(detail)
                        }
                    case .videos:
                        if detail.videos != nil {
                            self.videosSection(detail)
                        }
                    case .playlists:
                        if detail.playlists != nil {
                            self.playlistsSection(detail)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListHeaderHeight, 0)
        }
    }

    private func albumsSection(_ detail: ArtistDetail) -> some View {
        let albums = Array((detail.albums ?? []).prefix(self.maxAlbums))
        return Section {
            self.albumsSectionHeader(detail)
                .listRowBackground(Color.black)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowSeparator(.hidden)

            ForEach(Array(albums.enumerated()), id: \.element.id) { index, album in
                if self.source.config.data?.getAlbum != nil {
                    NavigationLink {
                        TracklistView(
                            tracklist: Tracklist(album: album, mediaSourceName: self.source.name),
                            source: self.source
                        )
                    } label: {
                        AlbumRow(album: album)
                            .alignmentGuide(.listRowSeparatorTrailing) { $0[.trailing] }
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.black)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowSeparatorTint(index == albums.count - 1 ? .clear : Color(.systemGray5))
                    .padding(.trailing, 16)
                } else {
                    AlbumRow(album: album)
                        .alignmentGuide(.listRowSeparatorTrailing) { $0[.trailing] - 16 }
                        .listRowBackground(Color.black)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowSeparatorTint(index == albums.count - 1 ? .clear : Color(.systemGray5))
                }
            }
        }
    }

    private func songsSection(_ detail: ArtistDetail) -> some View {
        let songs = Array((detail.songs ?? []).prefix(self.maxSongs))
        return Section {
            self.songsSectionHeader(detail)
                .listRowBackground(Color.black)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowSeparator(.hidden)

            ForEach(Array(songs.enumerated()), id: \.element.id) { index, track in
                Button {
                    self.playTrack(track, from: songs)
                } label: {
                    TrackRow(
                        track: track,
                        isSelected: PlaybackService.shared.currentTrack?.url == track.url && track.url != nil,
                        isLoading: PlaybackService.shared.isLoading,
                        isPlaying: PlaybackService.shared.isPlaying
                    )
                    .alignmentGuide(.listRowSeparatorTrailing) { $0[.trailing] - 16 }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.black)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowSeparatorTint(index == songs.count - 1 ? .clear : Color(.systemGray5))
            }
        }
    }

    private func videosSection(_ detail: ArtistDetail) -> some View {
        let videos = Array((detail.videos ?? []).prefix(self.maxVideos))
        return Section {
            self.videosSectionHeader(detail)
                .listRowBackground(Color.black)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowSeparator(.hidden)

            ForEach(Array(videos.enumerated()), id: \.element.id) { index, track in
                Button {
                    self.playTrack(track, from: videos)
                } label: {
                    TrackRow(
                        track: track,
                        isSelected: PlaybackService.shared.currentTrack?.url == track.url && track.url != nil,
                        isLoading: PlaybackService.shared.isLoading,
                        isPlaying: PlaybackService.shared.isPlaying
                    )
                    .alignmentGuide(.listRowSeparatorTrailing) { $0[.trailing] - 16 }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.black)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowSeparatorTint(index == videos.count - 1 ? .clear : Color(.systemGray5))
            }
        }
    }

    private func playlistsSection(_ detail: ArtistDetail) -> some View {
        let playlists = Array((detail.playlists ?? []).prefix(self.maxPlaylists))
        return Section {
            self.playlistsSectionHeader(detail)
                .listRowBackground(Color.black)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowSeparator(.hidden)

            ForEach(Array(playlists.enumerated()), id: \.element.id) { index, playlist in
                if self.source.config.data?.getPlaylist != nil {
                    NavigationLink {
                        TracklistView(
                            tracklist: Tracklist(playlist: playlist, mediaSourceName: self.source.name),
                            source: self.source
                        )
                    } label: {
                        PlaylistRow(playlist: playlist)
                            .alignmentGuide(.listRowSeparatorTrailing) { $0[.trailing] }
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.black)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowSeparatorTint(index == playlists.count - 1 ? .clear : Color(.systemGray5))
                    .padding(.trailing, 16)
                } else {
                    PlaylistRow(playlist: playlist)
                        .alignmentGuide(.listRowSeparatorTrailing) { $0[.trailing] - 16 }
                        .listRowBackground(Color.black)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowSeparatorTint(index == playlists.count - 1 ? .clear : Color(.systemGray5))
                }
            }
        }
    }

    private var albumsIcon: String {
        if #available(iOS 26.0, *) {
            return "music.note.square.stack.fill"
        } else {
            return "square.stack.fill"
        }
    }

    private func albumsSectionHeader(_ detail: ArtistDetail) -> some View {
        let hasScript = self.source.config.data?.getAlbumsForArtist != nil
        let albums = detail.albums ?? []
        return self.sectionHeaderLabel(title: "Albums", icon: self.albumsIcon)
            .background(
                NavigationLink(destination: TracklistListView(
                    artist: self.artist,
                    artistDetail: detail,
                    source: self.source,
                    title: "Albums",
                    preloadedAlbums: hasScript ? nil : albums,
                    fallbackAlbums: albums
                )) { EmptyView() }
                    .opacity(0)
            )
    }

    private func songsSectionHeader(_ detail: ArtistDetail) -> some View {
        let hasScript = self.source.config.data?.getSongsForArtist != nil
        let songs = detail.songs ?? []
        let tracklist = Tracklist(
            artist: self.artist,
            type: .artistSongs(self.artist, detail),
            mediaSourceName: self.source.name,
            tracks: hasScript ? nil : songs
        )
        return self.sectionHeaderLabel(title: "Songs", icon: "music.note")
            .background(
                NavigationLink(destination: TracklistView(
                    tracklist: tracklist,
                    source: self.source,
                    fallbackTracks: songs
                )) { EmptyView() }
                    .opacity(0)
            )
    }

    private func videosSectionHeader(_ detail: ArtistDetail) -> some View {
        let hasScript = self.source.config.data?.getVideosForArtist != nil
        let videos = detail.videos ?? []
        let tracklist = Tracklist(
            artist: self.artist,
            type: .artistVideos(self.artist, detail),
            mediaSourceName: self.source.name,
            tracks: hasScript ? nil : videos
        )
        return self.sectionHeaderLabel(title: "Videos", icon: "video.fill")
            .background(
                NavigationLink(destination: TracklistView(
                    tracklist: tracklist,
                    source: self.source,
                    fallbackTracks: videos
                )) { EmptyView() }
                    .opacity(0)
            )
    }

    private func playlistsSectionHeader(_ detail: ArtistDetail) -> some View {
        let hasScript = self.source.config.data?.getPlaylistsForArtist != nil
        let playlists = detail.playlists ?? []
        return self.sectionHeaderLabel(title: "Playlists", icon: "music.note.list")
            .background(
                NavigationLink(destination: TracklistListView(
                    artist: self.artist,
                    artistDetail: detail,
                    source: self.source,
                    title: "Playlists",
                    preloadedPlaylists: hasScript ? nil : playlists,
                    fallbackPlaylists: playlists
                )) { EmptyView() }
                    .opacity(0)
            )
    }

    private func sectionHeaderLabel(title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(.purp)
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            Image(systemName: "arrow.right")
                .font(.headline)
                .foregroundColor(.purp)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.fill")
                .font(.system(size: 40))
                .foregroundColor(Color(.systemGray5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.red)
            Text(message)
                .font(.callout)
                .foregroundColor(Color(.systemGray))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func playTrack(_ track: Track, from tracks: [Track]) {
        PlaybackService.shared.playTrack(track, queue: tracks, mediaSource: self.source)
    }
}
