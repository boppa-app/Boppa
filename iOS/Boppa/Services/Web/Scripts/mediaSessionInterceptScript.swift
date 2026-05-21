import WebKit

func getMediaSessionInterceptScript(messageHandlerName: String) -> WKUserScript {
    let script = """
    (function() {
        if (!('mediaSession' in navigator)) return;

        var originalSetActionHandler = navigator.mediaSession.setActionHandler.bind(navigator.mediaSession);
        var protectedActions = new Set(['play', 'pause', 'previoustrack', 'nexttrack', 'seekbackward', 'seekforward']);

        navigator.mediaSession.setActionHandler = function(action, handler) {
            if (protectedActions.has(action)) return;
            originalSetActionHandler(action, handler);
        };

        originalSetActionHandler('play', function() {
            window.webkit.messageHandlers.\(messageHandlerName).postMessage({type: 'playCommand'});
        });
        originalSetActionHandler('pause', function() {
            window.webkit.messageHandlers.\(messageHandlerName).postMessage({type: 'pauseCommand'});
        });
        originalSetActionHandler('seekbackward', null);
        originalSetActionHandler('seekforward', null);
        originalSetActionHandler('previoustrack', function() {
            window.webkit.messageHandlers.\(messageHandlerName).postMessage({type: 'previoustrackCommand'});
        });
        originalSetActionHandler('nexttrack', function() {
            window.webkit.messageHandlers.\(messageHandlerName).postMessage({type: 'nexttrackCommand'});
        });

        // Intercept playbackState so media sources can't override our state
        var playbackStateDescriptor = Object.getOwnPropertyDescriptor(navigator.mediaSession.__proto__, 'playbackState')
            || Object.getOwnPropertyDescriptor(navigator.mediaSession, 'playbackState');
        window.__boppaOriginalPlaybackStateSetter = playbackStateDescriptor && playbackStateDescriptor.set
            ? playbackStateDescriptor.set.bind(navigator.mediaSession) : null;
        window.__boppaPlaybackState = 'paused';
        if (window.__boppaOriginalPlaybackStateSetter) {
            window.__boppaOriginalPlaybackStateSetter.call(navigator.mediaSession, 'paused');
            Object.defineProperty(navigator.mediaSession, 'playbackState', {
                get: function() { return window.__boppaPlaybackState; },
                set: function(val) {
                    // No-op: only allow changes via __boppaOriginalPlaybackStateSetter
                },
                configurable: true
            });
        }

        // Intercept setPositionState so media sources can't override our position info
        window.__boppaOriginalSetPositionState = navigator.mediaSession.setPositionState.bind(navigator.mediaSession);
        window.__boppaDuration = 0;
        window.__boppaPlaybackRate = 1.0;
        window.__boppaPosition = 0;
        window.__boppaPositionTimestamp = Date.now();
        window.__boppaGetCurrentPosition = function() {
            var elapsed = (Date.now() - window.__boppaPositionTimestamp) / 1000.0;
            var pos = window.__boppaPosition + elapsed * window.__boppaPlaybackRate;
            return Math.max(0, Math.min(pos, window.__boppaDuration || pos));
        };
        navigator.mediaSession.setPositionState = function(state) {
            // No-op: only allow calls via __boppaOriginalSetPositionState
        };

        // Timer to update mediaSession position state every 250ms
        setInterval(function() {
            if (window.__boppaOriginalSetPositionState && window.__boppaDuration > 0) {
                try {
                    var pos = window.__boppaGetCurrentPosition ? window.__boppaGetCurrentPosition() : window.__boppaPosition;
                    window.__boppaOriginalSetPositionState.call(navigator.mediaSession, {
                        duration: window.__boppaDuration,
                        playbackRate: window.__boppaPlaybackRate || 1.0,
                        position: Math.max(0, Math.min(pos, window.__boppaDuration))
                    });
                } catch (e) {}
            }
        }, 250);

        // Intercept metadata setter to maintain control over Now Playing info
        var metadataDescriptor = Object.getOwnPropertyDescriptor(navigator.mediaSession.__proto__, 'metadata')
            || Object.getOwnPropertyDescriptor(navigator.mediaSession, 'metadata');
        var originalMetadataSetter = metadataDescriptor && metadataDescriptor.set;
        var boppaMetadata = new MediaMetadata({ title: 'Title', artist: 'Artist' });

        if (originalMetadataSetter) {
            originalMetadataSetter.call(navigator.mediaSession, boppaMetadata);
            Object.defineProperty(navigator.mediaSession, 'metadata', {
                get: function() { return boppaMetadata; },
                set: function(val) {
                    // Intercept: always set our controlled metadata via the real setter
                    originalMetadataSetter.call(navigator.mediaSession, boppaMetadata);
                },
                configurable: true
            });
        } else {
            navigator.mediaSession.metadata = boppaMetadata;
        }

        // Artwork preloading: create/remove hidden <img> elements to cache artwork
        window.__boppaArtworkHash = function(url) {
            var hash = 0;
            for (var i = 0; i < url.length; i++) {
                var chr = url.charCodeAt(i);
                hash = ((hash << 5) - hash) + chr;
                hash |= 0;
            }
            return 'boppa-artwork-' + Math.abs(hash).toString(36);
        };

        window.__boppaPreloadArtwork = function(url) {
            if (!url) return;
            var id = window.__boppaArtworkHash(url);
            if (document.getElementById(id)) return;
            var img = document.createElement('img');
            img.id = id;
            img.src = url;
            img.style.cssText = 'position:absolute;width:1px;height:1px;opacity:0;pointer-events:none;';
            document.body.appendChild(img);
        };

        window.__boppaRemoveArtwork = function(url) {
            if (!url) return;
            var id = window.__boppaArtworkHash(url);
            var el = document.getElementById(id);
            if (el) el.remove();
        };
    })();
    """
    return WKUserScript(
        source: script,
        injectionTime: .atDocumentStart,
        forMainFrameOnly: false
    )
}
