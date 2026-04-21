import SwiftUI

struct ArtistDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = ArtistDetailViewModel()
    @State private var trackForActions: Track?
    @State private var pendingArtist: Artist?
    @State private var pendingTracklist: Tracklist?

    let artist: Artist
    let mediaSource: MediaSource

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
                mediaSource: self.mediaSource
            )
        }
        .sheet(item: self.$trackForActions) { track in
            TrackActionsSheet(
                track: track,
                mediaSource: self.mediaSource,
                onArtistSelected: { artist in self.pendingArtist = artist },
                onAlbumSelected: { tracklist in self.pendingTracklist = tracklist }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color(.systemGray6))
        }
        .navigationDestination(item: self.$pendingArtist) { artist in
            ArtistDetailView(artist: artist, mediaSource: self.mediaSource)
        }
        .navigationDestination(item: self.$pendingTracklist) { tracklist in
            TracklistView(
                tracklist: Tracklist(
                    id: tracklist.id,
                    mediaSourceId: self.mediaSource.id,
                    title: tracklist.title,
                    subtitle: tracklist.subtitle,
                    artworkUrl: tracklist.artworkUrl,
                    metadata: tracklist.metadata,
                    tracklistType: tracklist.tracklistType,
                    artists: tracklist.artists,
                    storedTracklist: TracklistService.shared.findStoredTracklist(id: tracklist.id, modelContext: self.modelContext)
                )
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

            ForEach(Array(albums.enumerated()), id: \.element.id) { index, tracklist in
                if self.mediaSource.config.data?.getAlbum != nil {
                    NavigationLink {
                        TracklistView(
                            tracklist: Tracklist(
                                id: tracklist.id,
                                mediaSourceId: self.mediaSource.id,
                                title: tracklist.title,
                                subtitle: tracklist.subtitle,
                                artworkUrl: tracklist.artworkUrl,
                                metadata: tracklist.metadata,
                                tracklistType: .album,
                                artists: tracklist.artists,
                                storedTracklist: TracklistService.shared.findStoredTracklist(id: tracklist.id, modelContext: self.modelContext)
                            )
                        )
                    } label: {
                        TracklistRow(tracklist: tracklist)
                            .alignmentGuide(.listRowSeparatorTrailing) { $0[.trailing] }
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.black)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowSeparatorTint(index == albums.count - 1 ? .clear : Color(.systemGray5))
                    .padding(.trailing, 16)
                } else {
                    TracklistRow(tracklist: tracklist)
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
                TrackRow(
                    track: track,
                    isSelected: PlaybackService.shared.currentTrack?.url == track.url && track.url != nil,
                    isLoading: PlaybackService.shared.isLoading,
                    isPlaying: PlaybackService.shared.isPlaying,
                    onTap: { self.playTrack(track, from: songs) },
                    onEllipsisTap: { self.trackForActions = track }
                )
                .alignmentGuide(.listRowSeparatorTrailing) { $0[.trailing] - 16 }
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
                TrackRow(
                    track: track,
                    isSelected: PlaybackService.shared.currentTrack?.url == track.url && track.url != nil,
                    isLoading: PlaybackService.shared.isLoading,
                    isPlaying: PlaybackService.shared.isPlaying,
                    onTap: { self.playTrack(track, from: videos) },
                    onEllipsisTap: { self.trackForActions = track }
                )
                .alignmentGuide(.listRowSeparatorTrailing) { $0[.trailing] - 16 }
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

            ForEach(Array(playlists.enumerated()), id: \.element.id) { index, tracklist in
                if self.mediaSource.config.data?.getPlaylist != nil {
                    NavigationLink {
                        TracklistView(
                            tracklist: Tracklist(
                                id: tracklist.id,
                                mediaSourceId: self.mediaSource.id,
                                title: tracklist.title,
                                subtitle: tracklist.subtitle,
                                artworkUrl: tracklist.artworkUrl,
                                metadata: tracklist.metadata,
                                tracklistType: .playlist,
                                artists: tracklist.artists,
                                storedTracklist: TracklistService.shared.findStoredTracklist(id: tracklist.id, modelContext: self.modelContext)
                            )
                        )
                    } label: {
                        TracklistRow(tracklist: tracklist)
                            .alignmentGuide(.listRowSeparatorTrailing) { $0[.trailing] }
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.black)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowSeparatorTint(index == playlists.count - 1 ? .clear : Color(.systemGray5))
                    .padding(.trailing, 16)
                } else {
                    TracklistRow(tracklist: tracklist)
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
        return self.sectionHeaderLabel(title: "Albums", icon: self.albumsIcon)
            .background(
                NavigationLink(destination: TracklistListView(
                    artist: self.artist,
                    artistDetail: detail,
                    mediaSource: self.mediaSource,
                    type: .albums,
                    title: "Albums"
                )) { EmptyView() }
                    .opacity(0)
            )
    }

    private func songsSectionHeader(_ detail: ArtistDetail) -> some View {
        let tracklist = Tracklist(
            id: "\(self.artist.id)-songs",
            mediaSourceId: self.mediaSource.id,
            title: "Songs",
            artworkUrl: self.artist.artworkUrl,
            tracklistType: .artistSongs,
            fromArtist: self.artist,
            artistDetail: detail
        )
        return self.sectionHeaderLabel(title: "Songs", icon: "music.note")
            .background(
                NavigationLink(destination: TracklistView(
                    tracklist: tracklist
                )) { EmptyView() }
                    .opacity(0)
            )
    }

    private func videosSectionHeader(_ detail: ArtistDetail) -> some View {
        let tracklist = Tracklist(
            id: "\(self.artist.id)-videos",
            mediaSourceId: self.mediaSource.id,
            title: "Videos",
            artworkUrl: self.artist.artworkUrl,
            tracklistType: .artistVideos,
            fromArtist: self.artist,
            artistDetail: detail
        )
        return self.sectionHeaderLabel(title: "Videos", icon: "video.fill")
            .background(
                NavigationLink(destination: TracklistView(
                    tracklist: tracklist
                )) { EmptyView() }
                    .opacity(0)
            )
    }

    private func playlistsSectionHeader(_ detail: ArtistDetail) -> some View {
        return self.sectionHeaderLabel(title: "Playlists", icon: "music.note.list")
            .background(
                NavigationLink(destination: TracklistListView(
                    artist: self.artist,
                    artistDetail: detail,
                    mediaSource: self.mediaSource,
                    type: .playlists,
                    title: "Playlists"
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
        PlaybackService.shared.playTrack(track, queue: tracks, mediaSource: self.mediaSource)
    }
}
