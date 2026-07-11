---
title: Media Sources
description: How a media source configuration teaches Boppa to search and play from a site.
nav: Overview
order: 10
category: Media Sources
---

# Media Sources

A media source config is a single YAML file that tells Boppa how to work with one site. This config provides JavaScript which Boppa executes in order to be able to search a site's catalog (songs, artists, etc.) and play media. This section documents the configuration format at a high level. To use a media source config developed by the community, check out [r/BoppaApp](https://reddit.com/r/BoppaApp).

## Contents of a configuration

```yaml
id: archive.org
version: 1.0.0
name: Internet Archive
url: archive.org
iconSvg: |-
  <svg>...</svg>
highlightColor: "#FFFFFF"
context: [ ... ] # optional: background WebView context gathering
data:
  search: { ... } # search.songs / .videos / .albums / .artists / .playlists
  list:   { ... } # list.album / .playlist / .artistSongs / .artistVideos / ...
  get:    { ... } # get.artist / .song / .video / .album / .playlist
playback:
  url: "https://..." # or html: "<!doctype html>..."
  userScripts: [ ... ]
  customUserAgent: null # optional
popup: { ... } # optional: named interactive login/verification flows
```

- **`id`**: a stable, unique identifier for the source (for example, `archive.org`). This is the primary key under which Boppa stores the source. Changing it causes Boppa to treat the configuration as an entirely new source, which breaks update detection and disconnects any library items saved under the previous id.
- **`version`**: a free-form string (semantic versioning is a reasonable convention). When a configuration is hosted at a stable URL and this value is incremented, Boppa's automatic update mechanism picks up the change. See [Publishing & Sharing](/docs/media-sources/publishing).
- **`name`**, **`url`**: the display name and the domain the source communicates with. `url` also determines the scope used for cookies in [context](/docs/media-sources/context-popups) gathering and in search, list, and get calls.
- **`iconSvg`**, **`highlightColor`**: optional branding shown in the source picker and in Settings.
- **`data`**: the JavaScript that powers search, browsing, and detail fetches. See [Search](/docs/media-sources/search) and [List & Get](/docs/media-sources/list-get).
- **`playback`**: the player page and its scripts. See [Playback](/docs/media-sources/playback).
- **`context`**, **`popup`**: optional, for sources that require a session before they function. See [Context & Popups](/docs/media-sources/context-popups).

A complete field-by-field reference, including which fields are required, is provided in [Config Reference](/docs/media-sources/config-reference).
