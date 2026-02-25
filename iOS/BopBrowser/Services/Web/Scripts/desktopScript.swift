import WebKit

func getDesktopScript() -> WKUserScript {
    let desktopScript = """
        document.addEventListener('DOMContentLoaded', function() {
            var viewportMeta = document.querySelector('meta[name="viewport"]');
            if (viewportMeta) {
                viewportMeta.remove();
            }
            
            var newViewport = document.createElement('meta');
            newViewport.name = 'viewport';
            newViewport.content = 'width=1920, initial-scale=1.0, minimum-scale=1.0, maximum-scale=1.0, user-scalable=no';
            document.head.appendChild(newViewport);
            
        });
        
        Object.defineProperty(window.screen, 'width', {
            get: function() { return 1920; },
            configurable: true
        });
        
        Object.defineProperty(window.screen, 'height', {
            get: function() { return 1080; },
            configurable: true
        });
        
        Object.defineProperty(window.screen, 'availWidth', {
            get: function() { return 1920; },
            configurable: true
        });
        
        Object.defineProperty(window.screen, 'availHeight', {
            get: function() { return 1080; },
            configurable: true
        });
        
        Object.defineProperty(window, 'innerWidth', {
            get: function() { return 1920; },
            configurable: true
        });
        
        Object.defineProperty(window, 'innerHeight', {
            get: function() { return 1080; },
            configurable: true
        });
        
        Object.defineProperty(window, 'outerWidth', {
            get: function() { return 1920; },
            configurable: true
        });
        
        Object.defineProperty(window, 'outerHeight', {
            get: function() { return 1080; },
            configurable: true
        });
        
        Object.defineProperty(navigator, 'maxTouchPoints', {
            get: function() { return 0; },
            configurable: true
        });
        
        Object.defineProperty(navigator, 'platform', {
            get: function() { return 'MacIntel'; },
            configurable: true
        });
        
        if (window.PointerEvent) {
            var originalPointerEvent = window.PointerEvent;
            window.PointerEvent = function(type, eventInitDict) {
                if (eventInitDict) {
                    eventInitDict.pointerType = 'mouse';
                }
                return new originalPointerEvent(type, eventInitDict);
            };
        }
    """
    return WKUserScript(
        source: desktopScript,
        injectionTime: .atDocumentStart,
        forMainFrameOnly: false
    )
}
