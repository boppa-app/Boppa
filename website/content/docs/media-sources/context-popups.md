---
title: Context & Popups
description: How a media source gathers values periodically, and how it presents an interactive window when required.
nav: Context & Popups
order: 15
category: Media Sources
---

# Context & Popups

Some media sources may require a session before their search, browsing, or playback endpoints function correctly. Boppa provides two mechanisms for this: **context**, a background page loaded periodically to gather values, and **popups**, an interactive WebView a script can present when something requires direct user action.

## Context

```yaml
context:
  - title: Session Refresh
    url: "https://example.com/"
    intervalSeconds: 1800
    userScripts:
      - title: Capture Session
        content: |
          (function() {
            // compute a token, etc.
            window.boppaSetContextValues({ token: "..." });
            window.boppaContextDone();
          })();
        injectionTime: atDocumentEnd
    customUserAgent: null   # optional
```

`context` is a list, a source may declare more than one entry, each with its own URL and refresh interval. Boppa processes context entries for all enabled sources through a single shared hidden WebView, one at a time.

### When context is gathered

- Immediately when the app launches, for every media source that declares a `context`.
- Immediately when a media source with a `context` is added. The **Add Media Source** screen waits for this first pass to complete (or to time out) before finishing.
- Immediately whenever a media source is enabled.
- On a recurring timer, at the `intervalSeconds` configured for each entry, for as long as the app continues running.

Each context page load is allotted 60 seconds. If a script never signals completion within that window, Boppa abandons that load and moves on to the next queued item. Always call `window.boppaContextDone()` on success or `window.boppaContextFailed()` on failure, so a source does not become permanently stuck.

### The script contract

A context script has access to the same JavaScript environment described in [Script Environment](/docs/media-sources/script-environment), with four additional functions injected by Boppa:

| Function | Purpose |
| --- | --- |
| `window.boppaContextDone()` | Required on success. Signals that this context page has finished. Boppa tears down the page and moves to the next queued item. |
| `window.boppaSetContextValues(values)` | Optional, may be called more than once. Merges a plain object of string key/value pairs into this source's stored context. |
| `window.boppaContextFailed(message)` | Signals that gathering context failed. `message` is an optional string, a user-friendly error message to display to the user. |
| `window.boppaPopup(id)` | Optional. Presents the popup identified by `id`, see [Popups](#popups) below. |

Cookies do not need to be forwarded explicitly. Simply visiting a page that establishes or refreshes a session cookie is sufficient: Boppa reads the current cookie jar for the source's `url` domain immediately before every `search`, `list`, or `get` script call and supplies it as `params.cookies`. Use `boppaSetContextValues` only for values that must be computed or extracted.

### Using context values

Values stored with `boppaSetContextValues` are supplied to every subsequent `search`, `list`, and `get` script call as `params.context`, a plain object of the same key/value pairs:

```js
const token = params.context?.token;
```

## Popups

```yaml
popup:
  login:
    title: Log In
    url: "https://example.com/login"
    userScripts:
      - title: Detect Login
        content: |
          (function() {
            // watch for a successful login, then:
            window.boppaPopupDismiss();
          })();
        injectionTime: atDocumentEnd
    customUserAgent: null   # optional
```

`popup` is a map from an id to a `PopupConfig`. A popup is never shown on its own; it is presented only when a context or playback script calls `window.boppaPopup('<id>')`, where `<id>` matches a key in this map.

When triggered, Boppa presents a visible, scrollable WebView in a sheet, titled with the popup's `title`, with a manual dismiss button. Only one popup can be presented at a time; a second `boppaPopup` call while one is already showing is ignored.

### The script contract

| Function | Purpose |
| --- | --- |
| `window.boppaPopupDismiss()` | Optional. Dismisses the popup programmatically, for example once a login flow completes. The user can also dismiss it manually. |

### What happens on dismiss

- If the popup was triggered from a **context** script, the context page reloads and its 60-second timeout restarts.
- If the popup was triggered from a **playback** script, playback is stopped and the queue is cleared before the popup is shown, and the player page reloads once the popup is dismissed. Because of this, reserve playback-triggered popups for cases that genuinely require interruption, such as an expired session, rather than routine checks.
