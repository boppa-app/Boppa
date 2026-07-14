---
title: Testing & Debugging
description: How to iterate on a media source configuration and diagnose failures.
nav: Testing & Debugging
order: 17
category: Media Sources
---

# Testing & Debugging

Writing a media source configuration involves two different environments: the sandboxed JavaScript that runs `search`, `list`, and `get` scripts, and the ordinary web pages that back `playback`, `context`, and `popup`. This page covers the tools available for each.

## Errors when adding a configuration

Adding a media source can fail for a few distinct reasons, each surfaced with a specific message.

| Cause | Message |
| --- | --- |
| The entered text could not be parsed as a URL. | "The config URL could not be constructed" |
| The server returned a non-200 status. | "The server returned an error (HTTP `<code>`)", or a not-found-specific message for a 404. |
| The response was not valid YAML, or did not match the required schema. | "Malformed config: ..." followed by the specific missing key or type mismatch. |

The malformed-configuration message names the exact field that failed to decode, for example a missing required key or a value of the wrong type, which is generally enough to locate the problem directly in the YAML file.

## Errors from scripts

| Cause | Message |
| --- | --- |
| The script did not call `postResult` or `postError` within 30 seconds. | "Execution timed out" |
| The script threw, or an awaited promise rejected. | "Error: `<message>`" |
| `postResult` was called with something other than a plain object. | "Invalid result: ..." |

See [Script Environment](/docs/media-sources/script-environment) for the execution model these errors correspond to.

## Reading `console` output

Calls to `console.log`, `console.warn`, and `console.error` from `search`, `list`, `get`, `context`, and `popup` scripts are written to the system log. During development, this output appears directly in your development environment's console.

## Inspecting playback, context, and popup pages directly

Unlike data scripts, the pages behind `playback`, `context`, and `popup` are ordinary web content, and Boppa makes them inspectable with a standard remote web inspector, attached to the running app. This provides a full DOM inspector, console, and network panel for the actual page, which is the most direct way to debug a player page's own JavaScript, confirm that `window.boppaLoad` and the other [contract functions](/docs/media-sources/playback) are defined, or watch `postEvent` calls as they happen.

## Iterating on a configuration

The recommended workflow for actively developing a configuration is to serve the directory containing the YAML file locally with [Wrangler](https://developers.cloudflare.com/workers/wrangler/) (`wrangler pages dev .`), then expose that local server with a [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) (`cloudflared tunnel --url http://localhost:8788`), and add the source once from that URL. From then on, each change just needs an incremented `version` in the YAML and an app restart: Boppa's normal launch-time update check picks up the new version automatically, no remove-and-re-add required. There is no hot reload support at the moment.

Alternatively, you can import the `.yaml` file directly from your device. A media source added this way has no `configUrl`, so deleting and adding the file after each edit is the only way to update it.
