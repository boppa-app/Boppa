---
title: Config Reference
description: The full YAML schema for a media source configuration file.
nav: Config Reference
order: 11
category: Media Sources
---

# Config Reference

A media source config is a single YAML file. This page documents every top-level field. Boppa parses the file and decodes it against a schema. A field that is required and missing, or a value of the wrong type, causes the configuration to be rejected with an error.

## Top-level fields

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `id` | string | Yes | Stable, unique identifier for the source. Used as the primary key in Boppa's database. |
| `version` | string | Yes | Free-form version string. Compared on update checks; see [Publishing & Sharing](/docs/media-sources/publishing). |
| `name` | string | Yes | Display name shown throughout the app. |
| `url` | string | Yes | The domain the source communicates with, for example `archive.org`. Used to scope cookies for data scripts. |
| `iconSvg` | string | No | Raw SVG markup shown as the source's icon. |
| `highlightColor` | string | No | Hex color, for example `"#FFFFFF"`, used for accents associated with the source. |
| `context` | list | No | Background pages Boppa loads to gather cookies or tokens before the source is usable. See [Context & Popups](/docs/media-sources/context-popups). |
| `data` | object | Yes | The `search`, `list`, and `get` script groups. See [Search](/docs/media-sources/search) and [List & Get](/docs/media-sources/browsing). |
| `playback` | object | Yes | The player page and its bridge scripts. See [Playback](/docs/media-sources/playback). |
| `popup` | map | No | Named interactive WebView flows, keyed by an id a script can reference. See [Context & Popups](/docs/media-sources/context-popups). |

### `id`

A short, stable string, typically the source's domain (`archive.org`) or a reasonably specific slug. Boppa stores media sources keyed by `id`. Choose an `id` once and do not change it. It is reccomended to use the resource name of the FQDN as the `id` (example: `archive.org`). 

### `version`

An arbitrary string, most commonly a semantic version such as `1.0.0`. Boppa does not interpret its structure; it only compares it for equality against the previously stored value. When a configuration is fetched from its `configUrl` on app launch and the returned `version` differs from what is stored, Boppa applies the update, provided the source's per-source auto-update option is enabled; see [Publishing & Sharing](/docs/media-sources/publishing).

### `data`

A `DataScripts` object with three optional groups, `search`, `list`, and `get`. Each group is itself an object whose fields are either omitted or contain a string of JavaScript source. A capability that is omitted (for example, `search.artists`) is treated by the app as unsupported: the corresponding UI (an artist search tab, a "go to album" action, and so on) is simply not shown. See [Search](/docs/media-sources/search) and [List & Get](/docs/media-sources/browsing) for the full list of script names and their contracts.

### `playback`

A `PlaybackConfig` object with exactly one of `url` or `html`, plus a `userScripts` list and an
optional `customUserAgent`:

```yaml
playback:
  url: "https://example.com/player"   # OR:
  # html: |-
  #   <!doctype html><html>...</html>
  userScripts:
    - title: My Bridge Script
      content: |
        (function() { ... })();
      injectionTime: atDocumentStart
  customUserAgent: null   # optional
```

Supplying both `url` and `html`, or neither, causes the configuration to fail validation. See [Playback](/docs/media-sources/playback) for the full contract these scripts must implement.

### `context`

A list of `ContextConfig` objects, each describing a background page and the interval at which it is reloaded:

```yaml
context:
  - title: Session Refresh
    url: "https://example.com/"
    intervalSeconds: 1800
    userScripts:
      - title: Capture Session
        content: |
          (function() { ... window.boppaContextDone(); })();
        injectionTime: atDocumentEnd
    customUserAgent: null   # optional
```

See [Context & Popups](/docs/media-sources/context-popups) for the script
contract (`boppaContextDone`, `boppaSetContextValues`, `boppaPopup`) these scripts use.

### `popup`

A map from an arbitrary string id to a `PopupConfig` object, referenced from a context or playback script by calling `boppaPopup('<id>')`:

```yaml
popup:
  login:
    title: Log In
    url: "https://example.com/login"
    userScripts:
      - title: Detect Login
        content: |
          (function() { ... window.boppaPopupDismiss(); })();
        injectionTime: atDocumentEnd
    customUserAgent: null   # optional
```

See [Context & Popups](/docs/media-sources/context-popups) for how popups are presented and dismissed.

### `Script` objects

Both `context[].userScripts` and `playback.userScripts` and `popup.<id>.userScripts` are lists of `Script` objects:

| Field | Type | Description |
| --- | --- | --- |
| `title` | string | A human-readable label for the script. |
| `content` | string | The JavaScript source, injected into the page as a user script. |
| `injectionTime` | `atDocumentStart` \| `atDocumentEnd` | Whether the script runs before or after the page's own scripts and DOM construction. |
