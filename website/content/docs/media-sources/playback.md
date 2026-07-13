---
title: Playback
description: The player page and the JavaScript bridge that connects it to Boppa's controls.
nav: Playback
order: 14
category: Media Sources
---

# Playback

Boppa does not decode audio itself. Each media source describes a playback configuration which details a webpage, loaded in a hidden WebView, that is responsible for actually playing a track. Boppa drives this page through a small JavaScript bridge and listens for events it reports back. This page documents that contract in full.

## Configuring the player page

```yaml
playback:
  url: "https://example.com/embed-player"
  # or, instead of url:
  # html: |-
  #   <!doctype html>
  #   <html>...</html>
  userScripts:
    - title: Boppa Bridge
      content: |
        (function() { /* ... */ })();
      injectionTime: atDocumentStart
  customUserAgent: null # optional
```

Exactly one of `url` or `html` must be present.

- **`url`** loads an existing page, typically one already hosted by the source. This is appropriate when a page on the site already contains a working `<audio>` or `<video>` element and enough of its own JavaScript to load and play a given track.
- **`html`** supplies a small, self-contained document instead. This is appropriate when full control over the top-level document is required, or when the real player needs to be embedded in an `<iframe>`.

`userScripts` are injected into the page as described in [Config Reference: Script objects](/docs/media-sources/config-reference#script-objects). Scripts are injected into every frame of the document, including any `<iframe>` elements, not only the top-level frame. A script intended to run only inside an iframe should check `if (window === window.top) return;` at its start, and vice versa.

## Boppa ↔ WebView communication

### Functions Boppa calls

The player page (or its scripts) must define the following functions on `window`. Boppa calls these directly via JavaScript evaluation, a function that is missing is simply skipped, with no error surfaced.

| Function | Called when | Argument |
| --- | --- | --- |
| `window.boppaLoad(trackData)` | A new track is selected for playback. | An object describing the track, see [Track data](#track-data) below. |
| `window.boppaPlay()` | Playback should start or resume. | None. |
| `window.boppaPause()` | Playback should pause. | None. |
| `window.boppaSeek(ms)` | The playhead should move to a specific position. | Position in milliseconds. |
| `window.boppaStop()` | Playback has ended entirely (switching to different media source). | None. |

The object passed to `boppaLoad` has the following shape:

```js
{
  id: "00000000-0000-0000-0000-000000000000", // id of the song/video from search/get/list response
  title: "Track Title",
  subtitle: "Artist Name",
  duration: 213000, // milliseconds; 0 if unknown
  lowResArtworkUrl: "boppa-artwork://cache?url=...",
  highResArtworkUrl: "boppa-artwork://cache?url=...",
  url: "https://...",
  metadata: { any: "JSON object" },
  context: { key: "value" } // this source's gathered context values, {} if none
}
```

`metadata` is carried through unchanged from whichever search, list, or get script produced the track, see [Result shape](/docs/media-sources/search#result-shape). It defaults to `{}` if the script didn't set it.

`context` is this media source's stored context values, the same plain object of string key/value pairs passed to search, list, and get scripts as `params.context`, see [Using context values](/docs/media-sources/context-popups#using-context-values). It's included here so a player page can use them directly, for example to attach an auth header or cookie a script gathered, without Boppa needing a separate bridge for it. It's `{}` if the source declares no `context` or none has been gathered yet.

`lowResArtworkUrl` and `highResArtworkUrl` are rewritten by Boppa to a local `boppa-artwork://` URL that is served from Boppa's on-device image cache rather than fetched directly from the original source. Player pages should treat these as ordinary image URLs, for example including it in a [`MediaMetadata`](https://developer.mozilla.org/en-US/docs/Web/API/MediaMetadata) artwork entry. Boppa also proactively preloads artwork for nearby tracks in the queue by inserting hidden `<img>` elements into the player page in advance.

### Events the page reports

The page reports playback state back to Boppa by calling `window.postEvent(eventObj)`, a function Boppa injects automatically; it does not need to be defined by the configuration.

| `eventObj.type` | Meaning | Additional fields |
| --- | --- | --- |
| `"play"` | Playback has started or resumed. | None. |
| `"pause"` | Playback has paused. | None. |
| `"progress"` | The current playback position has changed. | `currentTime`, `duration` (seconds). |
| `"duration"` | The track's duration has been resolved. | `value` (seconds). |
| `"finish"` | The track has finished playing. Boppa advances to the next track in the queue. | None. |
| `"error"` | Playback has failed. | `message` (string, shown in logs). |

### Commands the page can request

[WebView controls AudioSession and NowPlayingInfo privately in iOS](https://bugs.webkit.org/show_bug.cgi?id=167788). As such, track navigation via NowPlayingInfo depends on Boppa's own queue and playback state, which the page has no visibility into. If you wish to implement track navigation in NowPlayingInfo you can do so by forwarding those requests back to Boppa by calling `window.postEvent` with one of the following types:

| `eventObj.type` | Effect | Additional fields |
| --- | --- | --- |
| `"previoustrackCommand"` | Requests that Boppa skip to the previous track. | None. |
| `"nexttrackCommand"` | Requests that Boppa skip to the next track. | None. |

Play, pause, and seek are different: since the page already owns `window.boppaPlay`/`window.boppaPause`/`window.boppaSeek`, an intercepted play/pause/seek request should just call them directly rather than going through Boppa.

## Triggering a popup from playback

If the player page needs to present an interactive flow mid-playback, for example to refresh an expired session, call `window.boppaPopup('<id>')`, where `<id>` matches a key in the configuration's top-level `popup` map. Boppa stops playback, presents the popup, and reloads the player page once the popup is dismissed. See [Context & Popups](/docs/media-sources/context-popups) for popup details.
