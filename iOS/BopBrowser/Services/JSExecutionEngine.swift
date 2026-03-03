import Foundation
import JavaScriptCore
import os

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "BopBrowser",
    category: "JSExecutionEngine"
)

@MainActor
final class JSExecutionEngine: NSObject {
    static let shared = JSExecutionEngine()

    private static let timeoutSeconds: TimeInterval = 30

    override private init() {
        super.init()
    }

    func execute(
        script: String,
        context: [String: Any]
    ) async throws -> [String: Any] {
        return try await withCheckedThrowingContinuation { continuation in
            let jsContext = JSContext()!

            self.installExceptionHandler(jsContext)

            var hasCompleted = false

            let postResult: @convention(block) (JSValue) -> Void = { value in
                guard !hasCompleted else { return }
                hasCompleted = true

                guard let dict = value.toDictionary() as? [String: Any] else {
                    continuation.resume(throwing: JSExecutionError.invalidResult(detail: "postResult argument is not a valid dictionary"))
                    return
                }
                continuation.resume(returning: dict)
            }

            let postError: @convention(block) (JSValue) -> Void = { value in
                guard !hasCompleted else { return }
                hasCompleted = true

                let message = value.toString() ?? "Unknown JS error"
                continuation.resume(throwing: JSExecutionError.scriptError(detail: message))
            }

            jsContext.setObject(postResult, forKeyedSubscript: "__postResult" as NSString)
            jsContext.setObject(postError, forKeyedSubscript: "__postError" as NSString)

            self.installFetch(in: jsContext)
            self.installContext(in: jsContext, context: context)
            self.installHelpers(in: jsContext)

            let wrappedScript = """
            (async () => {
                try {
                    \(script)
                } catch (e) {
                    postError(e.message || String(e));
                }
            })();
            """

            logger.info("Executing JS script in JSContext")
            jsContext.evaluateScript(wrappedScript)

            Task { [weak self] in
                try? await Task.sleep(for: .seconds(Self.timeoutSeconds))
                guard !hasCompleted else { return }
                hasCompleted = true
                logger.warning("JS execution timed out after \(Self.timeoutSeconds)s")
                continuation.resume(throwing: JSExecutionError.timeout)
            }
        }
    }

    private func installExceptionHandler(_ jsContext: JSContext) {
        jsContext.exceptionHandler = { [weak self] _, exception in
            let message = exception?.toString() ?? "Unknown JS exception"
            logger.error("JS exception: \(message)")
        }
    }

    private func installContext(in jsContext: JSContext, context: [String: Any]) {
        if let data = try? JSONSerialization.data(withJSONObject: context),
           let json = String(data: data, encoding: .utf8)
        {
            jsContext.evaluateScript("var context = \(json);")
        } else {
            jsContext.evaluateScript("var context = {};")
        }
    }

    private func installHelpers(in jsContext: JSContext) {
        jsContext.evaluateScript("""
        function postResult(data) { __postResult(data); }
        function postError(message) { __postError(message); }
        """)
    }

    private func installFetch(in jsContext: JSContext) {
        let fetchBlock: @convention(block) (String, JSValue?) -> JSValue = { urlString, options in
            Self.createPromise(in: jsContext) { resolve, reject in
                guard let request = Self.buildRequest(urlString: urlString, options: options) else {
                    reject.call(withArguments: ["Invalid URL or unsupported scheme: \(urlString)"])
                    return
                }

                logger.info("JS fetch: \(request.httpMethod ?? "GET") \(urlString)")

                Task {
                    do {
                        let (data, response) = try await URLSession.shared.data(for: request)
                        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                        logger.info("JS fetch response: \(statusCode) (\(data.count) bytes)")

                        let responseObj = Self.buildResponseObject(in: jsContext, data: data, statusCode: statusCode)
                        resolve.call(withArguments: [responseObj])
                    } catch {
                        logger.error("JS fetch error: \(error.localizedDescription)")
                        reject.call(withArguments: [error.localizedDescription])
                    }
                }
            }
        }

        jsContext.setObject(fetchBlock, forKeyedSubscript: "fetch" as NSString)
    }

    private static func buildRequest(urlString: String, options: JSValue?) -> URLRequest? {
        guard let url = URL(string: urlString),
              url.scheme == "http" || url.scheme == "https"
        else { return nil }

        var request = URLRequest(url: url)

        if let options, !options.isUndefined, !options.isNull {
            if let method = options.forProperty("method"), !method.isUndefined, !method.isNull {
                request.httpMethod = method.toString()
            }
            if let headers = options.forProperty("headers"), !headers.isUndefined, !headers.isNull,
               let headersDict = headers.toDictionary() as? [String: String]
            {
                for (key, value) in headersDict {
                    request.setValue(value, forHTTPHeaderField: key)
                }
            }
            if let body = options.forProperty("body"), !body.isUndefined, !body.isNull {
                request.httpBody = body.toString()?.data(using: .utf8)
            }
        }

        return request
    }

    private static func buildResponseObject(in jsContext: JSContext, data: Data, statusCode: Int) -> JSValue {
        let responseObj = JSValue(newObjectIn: jsContext)!
        responseObj.setObject(statusCode, forKeyedSubscript: "status" as NSString)
        responseObj.setObject(statusCode >= 200 && statusCode < 300, forKeyedSubscript: "ok" as NSString)

        let jsonBlock: @convention(block) () -> JSValue = {
            Self.createPromise(in: jsContext) { resolve, reject in
                if let parsed = try? JSONSerialization.jsonObject(with: data),
                   let jsValue = JSValue(object: parsed, in: jsContext)
                {
                    resolve.call(withArguments: [jsValue])
                } else {
                    reject.call(withArguments: ["Failed to parse response as JSON"])
                }
            }
        }

        let textBlock: @convention(block) () -> JSValue = {
            Self.createPromise(in: jsContext) { resolve, _ in
                let text = String(data: data, encoding: .utf8) ?? ""
                resolve.call(withArguments: [text])
            }
        }

        responseObj.setObject(jsonBlock, forKeyedSubscript: "json" as NSString)
        responseObj.setObject(textBlock, forKeyedSubscript: "text" as NSString)

        return responseObj
    }

    private static func createPromise(in jsContext: JSContext, executor: @escaping (JSValue, JSValue) -> Void) -> JSValue {
        let promiseConstructor = jsContext.objectForKeyedSubscript("Promise")!
        let executorBlock: @convention(block) (JSValue, JSValue) -> Void = { resolve, reject in
            executor(resolve, reject)
        }
        return promiseConstructor.construct(withArguments: [unsafeBitCast(executorBlock, to: AnyObject.self)])
    }
}
