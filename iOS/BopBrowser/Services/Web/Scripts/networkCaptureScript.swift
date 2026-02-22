import WebKit

func getNetworkCaptureScript(captures: [QueryParameterCapture], messageHandlerName: String) -> WKUserScript {
    let captureConfigDicts: [[String: String]] = captures.map { capture in
        [
            "pattern": capture.pattern,
            "value": capture.value,
            "keyMapping": capture.keyMapping.rawValue,
        ]
    }
    let jsonData = try! JSONSerialization.data(withJSONObject: captureConfigDicts, options: [])
    let captureConfigsJSON = String(data: jsonData, encoding: .utf8)!

    let script = """
        (function() {
            'use strict';

            const captureConfigs = \(captureConfigsJSON);
            console.log('[BopBrowser:NetworkCapture] Initialized with ' + captureConfigs.length + ' capture config(s)');
            captureConfigs.forEach(function(c) {
                console.log('[BopBrowser:NetworkCapture]   - keyMapping: ' + c.keyMapping + ', param: ' + c.value + ', pattern: ' + c.pattern);
            });

            function processURL(urlString, source) {
                console.log('[BopBrowser:NetworkCapture] [' + source + '] Intercepted: ' + urlString);
                for (const config of captureConfigs) {
                    try {
                        const regex = new RegExp(config.pattern);
                        const matched = regex.test(urlString);
                        if (matched) {
                            console.log('[BopBrowser:NetworkCapture] Pattern MATCHED for ' + config.keyMapping + ': ' + config.pattern);
                            try {
                                const url = new URL(urlString);
                                const paramValue = url.searchParams.get(config.value);
                                if (paramValue) {
                                    console.log('[BopBrowser:NetworkCapture] Extracted ' + config.keyMapping + ' = ' + paramValue);
                                    window.webkit.messageHandlers.\(messageHandlerName).postMessage({
                                        keyMapping: config.keyMapping,
                                        value: paramValue
                                    });
                                } else {
                                    console.log('[BopBrowser:NetworkCapture] Pattern matched but param "' + config.value + '" not found in URL query string');
                                }
                            } catch(e) {
                                console.log('[BopBrowser:NetworkCapture] URL parsing failed for: ' + urlString + ' - ' + e.message);
                            }
                        }
                    } catch(e) {
                        console.log('[BopBrowser:NetworkCapture] Regex error for pattern ' + config.pattern + ': ' + e.message);
                    }
                }
            }

            const originalFetch = window.fetch;
            window.fetch = function() {
                const url = arguments[0];
                if (typeof url === 'string') {
                    processURL(url, 'fetch');
                } else if (url instanceof Request) {
                    processURL(url.url, 'fetch');
                }
                return originalFetch.apply(this, arguments);
            };
            console.log('[BopBrowser:NetworkCapture] fetch() patched');

            const originalXHROpen = XMLHttpRequest.prototype.open;
            XMLHttpRequest.prototype.open = function() {
                const url = arguments[1];
                if (typeof url === 'string') {
                    try {
                        const resolved = new URL(url, window.location.href).href;
                        processURL(resolved, 'XHR');
                    } catch(e) {
                        processURL(url, 'XHR');
                    }
                }
                return originalXHROpen.apply(this, arguments);
            };
            console.log('[BopBrowser:NetworkCapture] XMLHttpRequest.open() patched');
        })();
    """

    return WKUserScript(
        source: script,
        injectionTime: .atDocumentStart,
        forMainFrameOnly: false
    )
}
