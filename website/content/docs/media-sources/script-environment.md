---
title: Script Environment
description: The JavaScript runtime that data scripts execute in.
nav: Script Environment
order: 16
category: Media Sources
---

# Script Environment

Every data script in a media source config (`search`, `list`, `get`), executes inside a sandboxed JavaScript engine. This is not a web page, there is no DOM and no access to any browser API. The environment is intentionally minimal, providing only what is documented on this page.

## Lifecycle

Each script invocation runs in a brand-new engine instance. No state, whether a variable, a timer, or a cached value, persists from one call to the next, including between two calls to the same script. Any data a script needs across calls must be re-derived (or passed forward through the [pagination](/docs/media-sources/search#pagination) continuationmechanism).

A script is given 30 seconds to call `postResult` or `postError`. If it does neither within that window, execution is abandoned and a timeout error is surfaced to the app.

Internally, the script's source is wrapped as follows before it runs:

```js
(async () => {
  try {
    /* your script's content */
  } catch (e) {
    postError(e.message || String(e));
  }
})();
```

This means a synchronous throw, or an awaited rejected promise, is caught automatically and reported as an error. A promise that is created but never awaited or explicitly handled, however, is not covered by this `try`/`catch`. Always `await` asynchronous work, or attach an explicit `.catch`, rather than leaving a promise chain unattended.

## `params`

A global `params` object is populated before the script runs. Its contents depend on which script is executing, see the page for that script group for the exact fields ([Search](/docs/media-sources/search), [List & Get](/docs/media-sources/list-get)). Two fields are common to most data scripts:

| Field | Description |
| --- | --- |
| `params.cookies` | An object mapping cookie name to value, scoped to the media source's `url` domain, read from the mobile cookie jar immediately before the script runs. |
| `params.context` | An object of string key/value pairs previously stored via `boppaSetContextValues`, present only if the source declares a `context` and values have been gathered. |

## `fetch`

A restricted implementation of the standard `fetch` API is available:

```js
const response = await fetch(url, {
  method: "GET", // optional, defaults to GET
  headers: { "X-Custom": "value" }, // optional, object of string to string
  body: "raw string body" // optional
});

response.status; // number
response.ok; // boolean, true for 2xx status codes
const data = await response.json(); // parses the response body as JSON
const text = await response.text(); // returns the response body as a string
```

Only `http:` and `https:` URLs are accepted, any other scheme rejects the returned promise. Cookies are not automatically attached to `fetch` requests, if a request needs the source's session, read the relevant value from `params.cookies` and set it explicitly via a `headers` entry.

By default, `fetch` only permits requests to the media source's own `url`. If a script needs to reach additional domains, for example a separate API host, list them in the configuration's top-level [`allowedUrls`](/docs/media-sources/config-reference#allowedurls).

## Timers

`setTimeout(callback, delayMs)` and `clearTimeout(id)` are available with their standard signatures. Because each script invocation has a fixed 30-second budget, timers are useful mainly for short delays within a single call, not for anything intended to persist.

## `console`

`console.log`, `console.info`, `console.debug`, `console.warn`, and `console.error` are all available. Arguments that are objects are serialized with `JSON.stringify`, everything else is converted to a string and joined with spaces. Output is written to the system log and is primarily useful when inspecting logs directly.

## `postResult` and `postError`

Every script must call exactly one of these two global functions before its time budget expires.

- **`postResult(data)`**: signals success. `data` must be a plain object, its exact required shape depends on which script is executing.
- **`postError(message)`**: signals failure with a specific, human-readable message string, which is what the app displays or logs.

When `postResult` is called, Boppa also records the order in which keys were set on the returned object (its JavaScript property insertion order). This is used in exactly one place: the order of the `songs`, `albums`, `videos`, and `playlists` keys returned from [`get.artist`](/docs/media-sources/list-get#getartist) determines the order the corresponding sections are displayed on an artist's page.
