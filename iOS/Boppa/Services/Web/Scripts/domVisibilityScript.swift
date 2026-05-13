import WebKit

func getDomVisibilityScript() -> WKUserScript {
    let visibilityScript = """
        (function() {
            'use strict';
            
            Object.defineProperty(document, 'hidden', {
                configurable: true,
                get: function() {
                return false;
                }
            });
            
            Object.defineProperty(document, 'visibilityState', {
                configurable: true,
                get: function() {
                return 'visible';
                }
            });
            
            if ('webkitHidden' in document) {
                Object.defineProperty(document, 'webkitHidden', {
                configurable: true,
                get: function() {
                    return false;
                }
                });
            }
            
            if ('webkitVisibilityState' in document) {
                Object.defineProperty(document, 'webkitVisibilityState', {
                configurable: true,
                get: function() {
                    return 'visible';
                }
                });
            }
            
            const originalAddEventListener = document.addEventListener;
            document.addEventListener = function(type, listener, options) {
                if (type === 'visibilitychange' || type === 'webkitvisibilitychange') {
                return originalAddEventListener.call(this, type, listener, options);
                }
                return originalAddEventListener.call(this, type, listener, options);
            };
            
            Object.defineProperty(document, 'hasFocus', {
                configurable: true,
                value: function() {
                return true;
                }
            });
        })();
    """
    return WKUserScript(
        source: visibilityScript,
        injectionTime: .atDocumentStart,
        forMainFrameOnly: false
    )
}
