---
title: Publishing & Sharing
description: Publishing a media source configuration, sharing it with others, and how Boppa applies updates.
nav: Publishing & Sharing
order: 18
category: Media Sources
---

# Publishing & Sharing

A media source configuration is a plain YAML file served over HTTP. There is no registration process and no build step, publishing a configuration means making the file reachable at a stable URL.

## Sharing a configuration

Direct users to the configuration's URL, or share it as a deep link that adds the media source config to Boppa directly. Visit [Add Media Source - Boppa](https://boppa.app/add-media-source) to create a deep link.

The [r/BoppaApp](https://reddit.com/r/BoppaApp) community on Reddit is the primary place to share a configuration and discover ones written by others.

## Keeping a configuration updated

Each time Boppa launches, it checks every added source that was originally added from a URL and has its per-source auto-update option enabled. For each such source, Boppa re-fetches the configuration from its original URL and compares the fetched `id` and `version` against what is currently stored.

- If the fetched `id` matches the stored `id` and the `version` differs, the update is applied: the source's name, domain, and configuration data are replaced, while locally held state, such as whether the source is enabled, its position in the source list, and any gathered context values, is preserved.
- If the fetched `id` does not match the stored `id`, the update is skipped. This is why `id` must never change between versions of the same configuration, see [Config Reference: id](/docs/media-sources/config-reference#id).
- If the `version` is unchanged, no update is applied.

To publish a new version of a configuration, edit the file at its existing URL and increment `version`. Users who added the source from that URL and have auto-update enabled will receive the change the next time they launch Boppa. The auto-update option for an individual source can be turned off from that source's detail screen in **Settings**, which pins it to whatever configuration is currently installed.
