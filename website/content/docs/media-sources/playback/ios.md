---
title: iOS Playback
description: Why iOS player pages need a silent keepalive audio element, and the constraints that shape how it's built.
nav: iOS
order: 15
category: Media Sources
---

# Now Playing Info

Traditionally, iOS apps utilize [MPRemoteCommandCenter](https://developer.apple.com/documentation/mediaplayer/mpremotecommandcenter) and [MPNowPlayingInfoCenter](https://developer.apple.com/documentation/mediaplayer/mpnowplayinginfocenter) to handle playback controls and integrate with iOS's Now Playing Info.

However, when using a WebView for audio playback, these will not work. [WebView controls AudioSession and NowPlayingInfo privately in iOS](https://bugs.webkit.org/show_bug.cgi?id=167788).

## Using `navigator.mediaSession`

The [Media Session API](https://developer.mozilla.org/en-US/docs/Web/API/MediaSession) is the web equivalent, and it's what a player page should use instead. Setting `navigator.mediaSession.metadata` to a `MediaMetadata` object (title, artist, artwork) populates Now Playing Info.

```javascript
navigator.mediaSession.metadata = new MediaMetadata({
  title: 'Title',
  artist: 'Artist',
  artwork: [{ src: 'https://example.com/example.png' }]
});
```

To modify play/pause, seek, and navigation controls, register the appropriate handlers on `navigator.mediaSession`:
```javascript
navigator.mediaSession.setActionHandler(
  'play' |
  'pause' |
  'previoustrack' | 
  'nexttrack' | 
  'seekto', 
  callback
)
```
These are what should call back into `window.boppaPlay`/`boppaPause`/`boppaSeek`, as well as `postEvent` for `previoustrackCommand`/`nexttrackCommand`.

`navigator.mediaSession.setPositionState()` drives the scrubber, and you can set `navigator.mediaSession.playbackState` to `'playing'`/`'paused'` on every play/pause to keep it in sync.

```javascript
navigator.mediaSession.setPositionState({
  duration: 213,
  position: 42,
  playbackRate: 1.0
});
navigator.mediaSession.playbackState = 'playing';
```

Crucially, Now Playing Info isn't owned by the page as a whole, it's owned by whichever specific `HTMLMediaElement` on the page holds an active `MediaElementSession`. If no such element actually exists and is playing, these calls succeed without erroring, but there's no session for iOS to route lock screen commands through.

## `AudioContext` and limitations

Web Audio API is an alternative to a plain `<audio>` element. `AudioContext` does participate in Now Playing Info, it owns its own [`PlatformMediaSession`](https://github.com/WebKit/WebKit/blob/cda8109a552b6f44949c4413be917c8d0923b7ce/Source/WebCore/Modules/webaudio/AudioContext.cpp#L134) and [merges in navigator.mediaSession metadata](https://github.com/WebKit/WebKit/blob/cda8109a552b6f44949c4413be917c8d0923b7ce/Source/WebCore/Modules/webaudio/AudioContext.cpp#L581).

But it has limited functionality with remote commands.

WebKit's [`AudioContext::didReceiveRemoteControlCommand()`](https://github.com/WebKit/WebKit/blob/cda8109a552b6f44949c4413be917c8d0923b7ce/Source/WebCore/Modules/webaudio/AudioContext.cpp#L512-L538) only handles Play/Pause, and handles them natively, by resuming/suspending the audio graph directly, without ever calling into `setActionHandler` callbacks.

`previoustrack`, `nexttrack`, and seek commands aren't implemented cases at all, they are no-ops. This is a gap in WebKit itself, not something fixable through a script. Contrast that with [`MediaElementSession::didReceiveRemoteControlCommand()`](https://github.com/WebKit/WebKit/blob/cda8109a552b6f44949c4413be917c8d0923b7ce/Source/WebCore/html/MediaElementSession.cpp#L1363-L1405), which does dispatch every remote command through to `setActionHandler`, a real `HTMLMediaElement` is the only path that gets you this.
