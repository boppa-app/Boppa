---
title: Search Scripts
description: The data.search scripts that power Boppa's Search tab, one per result category.
nav: Search
order: 12
category: Media Sources
---

# Search Scripts

The `data.search` object contains up to five scripts, one per search category. Each is optional;
a category with no script is simply not offered as a search tab for that source.

```yaml
data:
  search:
    songs: |
      # JavaScript code
    videos: |
      # JavaScript code
    albums: |
      # JavaScript code
    artists: |
      # JavaScript code
    playlists: |
      # JavaScript code
```

## Invocation

When a user types a query and selects a category, Boppa runs the corresponding script once per keystroke pause. Each script receives a global `params` object:

| Property | Type | Present when |
| --- | --- | --- |
| `params.query` | string | Always. |
| `params.cookies` | object | Always. A map of cookie name to value for the source's `url` domain. Empty if none are set. |
| `params.context` | object | Only if the media source declares a `context` and values have been gathered. See [Context & Popups](/docs/media-sources/context-popups). |
| `params.previousResult` | object | Only when fetching a subsequent page. See [Pagination](#pagination) below. |

The script must call the global `postResult(data)` function exactly once with the result, or `postError(message)` to signal failure. See [Script Environment](/docs/media-sources/script-environment) for the full JavaScript environment (`fetch`, timers, `console`, and so on) available to the script.

## Result shape

`postResult` must be called with an object containing an `items` array. The shape of each item
depends on the category.

### `songs`, `videos`

```js
postResult({
  items: [
    {
      id: "unique-id", // required
      title: "Track Title", // required
      subtitle: "Artist Name", // optional
      duration: 213000, // optional, milliseconds
      lowResArtworkUrl: "https://...", // optional
      highResArtworkUrl: "https://...", // optional
      url: "https://...", // optional
      artists: [ { id, name, lowResArtworkUrl, highResArtworkUrl } ], // optional
      albums:  [ { id, title, subtitle, lowResArtworkUrl, highResArtworkUrl } ] // optional
    }
  ]
});
```

`id` and `title` are the only required fields; every other field may be omitted. `url` is the value later passed to the [playback](/docs/media-sources/playback) page and may be any string the player page understands, such as a direct media URL or a custom identifier the player resolves itself. The nested `artists` and `albums` arrays let a search result carry enough information for Boppa to offer *"Go to Artist"* and *"Go to Album"* actions without an additional lookup.

### `albums`, `playlists`

```js
postResult({
  items: [
    {
      id: "unique-id", // required
      title: "Album Title", // required
      subtitle: "Artist Name", // optional
      year: 1975, // optional
      trackCount: 12, // optional
      lowResArtworkUrl: "https://...", // optional
      highResArtworkUrl: "https://..." // optional
    }
  ]
});
```

### `artists`

```js
postResult({
  items: [
    {
      id: "unique-id", // required
      name: "Artist Name", // required
      lowResArtworkUrl: "https://...", // optional
      highResArtworkUrl: "https://..." // optional
    }
  ]
});
```

## Pagination

To support infinite scroll, include any additional fields alongside `items` in the object passed to `postResult`. Boppa treats every field other than `items` as continuation state and, if at least one such field is non-null, stores it. When the user scrolls to the end of the current results, the same script runs again with `params.previousResult` set to exactly that object:

```js
const page = params.previousResult?.page ? params.previousResult.page + 1 : 1;

// ... fetch page ...

const result = { items: items };
if (items.length === pageSize) {
  result.page = page; // there may be more pages; continue
}
postResult(result); // omitting `page` signals there are no more pages
```

If no field besides `items` is present, or every such field is `null`, Boppa treats the result as the final page and does not request more.

## Errors

If the script throws, or an awaited promise rejects, Boppa surfaces the error message and the search category is left empty. Call `postError(message)` directly for a specific, user-relevant error message.
