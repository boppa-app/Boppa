---
title: List & Get Scripts
description: The data.list and data.get scripts that back album, playlist, and artist pages.
nav: List & Get
order: 13
category: Media Sources
---

# List & Get Scripts

Where `data.search` scripts answer "what matches this query", `data.list` and `data.get` scripts answer "what is inside this album, playlist, or artist" and "what are the details of this single item". Both groups run in the same JavaScript environment as search scripts, see [Script Environment](/docs/media-sources/script-environment) for the full list of globals available.

## `data.list`

```yaml
data:
  list:
    album: |
      // JavaScript code
    playlist: |
      // JavaScript code
    artistSongs: |
      // JavaScript code
    artistVideos: |
      // JavaScript code
    artistAlbums: |
      // JavaScript code
    artistPlaylists: |
      // JavaScript code
```

Each script is called with `params.id` set to the relevant media id (an album, playlist, or artist id, previously returned as `id` from a search or another list/get script), plus `params.cookies` and, if applicable, `params.context`, exactly as in [Search Scripts](/docs/media-sources/search).

`list.album`, `list.playlist`, `list.artistSongs`, and `list.artistVideos` all return a page of tracks and must call `postResult` with the same shape used by `search.songs`:

```js
postResult({
  items: [ /* track objects, same shape as search.songs items */ ],
  // any additional fields become params.previousResult on the next page
});
```

These four scripts support the same pagination contract described in [Search Scripts: Pagination](/docs/media-sources/search#pagination). When a user scrolls to the bottom of an album or playlist page, the script is called again with `params.previousResult` set to whatever non-`items` fields the previous call returned. When Boppa needs the complete track list at once, for example when saving an album to the library, it calls the script repeatedly until no continuation is returned and combines every page.

`list.artistAlbums` and `list.artistPlaylists` return a page of albums or playlists, using the same item shape as `search.albums` and `search.playlists`. These two are called once, when the corresponding section of an artist's page is opened, and are not paginated further in the current version of the app, any continuation field they return is currently unused.

## `data.get`

```yaml
data:
  get:
    artist: |
      // JavaScript code
    song: |
      // JavaScript code
    video: |
      // JavaScript code
    album: |
      // JavaScript code
    playlist: |
      // JavaScript code
```

### `get.artist`

Called with `params.id` set to the artist's media id whenever the user opens an artist page. This is the primary source of an artist's detail page content, the search result that led to the page generally carries only an id, a name, and artwork.

```js
postResult({
  lowResArtworkUrl: "https://...", // optional
  highResArtworkUrl: "https://...", // optional
  songs: [ /* track objects */ ], // optional
  albums: [ /* tracklist objects */ ], // optional
  videos: [ /* track objects */ ], // optional
  playlists: [ /* tracklist objects */ ] // optional
});
```

Each of `songs`, `albums`, `videos`, and `playlists` uses the same item shape as the corresponding search category. Any of the four may be omitted, the artist page only shows sections for which data was returned.

The order in which these four keys appear in the object passed to `postResult` determines the order the corresponding sections are displayed on the artist page. For example, returning `{ albums: [...], songs: [...] }` displays the Albums section before the Songs section.

### `get.song`, `get.video`

Called with `params.id` set to a track's media id. Returns a single track object, using the same shape as an item from `search.songs` (`id` and `title` are required, all other fields are optional). Boppa calls this to resolve a track's full metadata, most commonly to refresh an already-playing track's details.

```js
postResult({
  id: "unique-id",
  title: "Track Title",
  // ... same optional fields as a search.songs item
});
```

### `get.album`, `get.playlist`

Called with `params.id` set to the album or playlist's media id whenever its page is opened. Returns a single tracklist object, using the same shape as an item from `search.albums` or `search.playlists`. Boppa merges the returned fields into whatever metadata is already known about the tracklist (for example, from the search result or list item that led to this page), filling in anything the earlier metadata was missing, such as `trackCount` or artwork.

```js
postResult({
  id: "unique-id",
  title: "Album Title",
  subtitle: "Artist Name", // optional
  year: 1975, // optional, get.album only
  trackCount: 12, // optional
  lowResArtworkUrl: "https://...", // optional
  highResArtworkUrl: "https://..." // optional
});
```

## Errors

As with search scripts, a thrown error, a rejected promise, or a call to `postError(message)` surfaces as an error message in the relevant view. A `list` or `get` script that never calls `postResult` or `postError` times out after 30 seconds, see [Script Environment](/docs/media-sources/script-environment).
