import Foundation
import os

enum JSCodeGenerator {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "BopBrowser",
        category: "JSCodeGenerator"
    )
    private static let identifierPattern = /^[a-zA-Z_$][a-zA-Z0-9_$.]*$/
    private static let iframeId = "player-widget"

    static func generateHTML(config: WidgetPlaybackConfig, trackURL: String, messageHandlerName: String) -> String? {
        guard self.validateConfig(config) else {
            self.logger.error("Config validation failed — refusing to generate JS")
            return nil
        }

        let encodedURL = trackURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trackURL
        let postMessage = "window.webkit.messageHandlers.\(messageHandlerName).postMessage"

        let embedSrc = config.embedUrl.replacingOccurrences(of: "<TRACK_URL>", with: encodedURL)
        let initJS = self.generateInit(config: config)
        let eventJS = self.generateEventBindings(config: config, postMessage: postMessage)
        let commandJS = self.generateCommands(config: config)

        return """
            <!DOCTYPE html>
            <html>
            <head>
                <meta name="viewport" content="width=device-width, initial-scale=1">
                <script src="\(self.escapeHTML(config.scriptUrl))"></script>
            </head>
            <body style="margin:0;padding:0;">
                <iframe id="\(self.iframeId)" width="100%" height="166" scrolling="no"
                    frameborder="no" src="\(self.escapeHTML(embedSrc))">
                </iframe>
                <script>
                    \(initJS)
                    \(eventJS)
                    \(commandJS)
                </script>
            </body>
            </html>
        """
    }

    private static func validateConfig(_ config: WidgetPlaybackConfig) -> Bool {
        var valid = true

        valid = self.validateIdentifier(config.widgetInit.constructor, label: "init.constructor") && valid
        valid = self.validateIdentifier(config.eventBinding.method, label: "eventBinding.method") && valid
        valid = self.validateIdentifier(config.eventBinding.constantPrefix, label: "eventBinding.constantPrefix") && valid

        for event in config.events {
            valid = self.validateIdentifier(event.widgetEvent, label: "event.widgetEvent") && valid
            if let arg = event.callbackArg {
                valid = self.validateIdentifier(arg, label: "event.callbackArg") && valid
            }
            if let post = event.post {
                valid = self.validatePostMessage(post) && valid
            }
            if let actions = event.actions {
                for action in actions {
                    valid = self.validateReadyAction(action) && valid
                }
            }
        }

        valid = self.validateCommand(config.commands.play, label: "commands.play") && valid
        valid = self.validateCommand(config.commands.pause, label: "commands.pause") && valid
        valid = self.validateCommand(config.commands.seek, label: "commands.seek") && valid

        return valid
    }

    private static func validateIdentifier(_ value: String, label: String) -> Bool {
        guard value.wholeMatch(of: self.identifierPattern) != nil else {
            self.logger.error("Invalid identifier for \(label): '\(value)'")
            return false
        }
        return true
    }

    private static func validatePostMessage(_ post: PostMessage) -> Bool {
        var valid = true
        if let fields = post.fields {
            for (_, value) in fields {
                valid = self.validatePostMessageValue(value) && valid
            }
        }
        return valid
    }

    private static func validatePostMessageValue(_ value: PostMessageValue) -> Bool {
        switch value {
        case let .fieldExtraction(field, transform):
            var valid = self.validateIdentifier(field, label: "post.field")
            if let transform {
                valid = self.validateTransforms(transform) && valid
            }
            return valid
        case let .callbackArgRef(_, transform):
            if let transform {
                return self.validateTransforms(transform)
            }
            return true
        }
    }

    private static func validateTransforms(_ transforms: [ValueTransform]) -> Bool {
        var valid = true
        for transform in transforms {
            switch transform {
            case .divide, .multiply, .round:
                break
            case let .divideByField(field):
                valid = self.validateIdentifier(field, label: "transform.divideByField") && valid
            }
        }
        return valid
    }

    private static func validateCommand(_ command: WidgetCommand, label: String) -> Bool {
        return self.validateIdentifier(command.method, label: label)
    }

    private static func validateReadyAction(_ action: ReadyAction) -> Bool {
        switch action {
        case let .command(name):
            return self.validateIdentifier(name, label: "readyAction.command")
        case let .asyncMethod(method, post):
            var valid = self.validateIdentifier(method, label: "readyAction.asyncMethod")
            valid = self.validatePostMessage(post) && valid
            return valid
        }
    }

    private static func generateInit(config: WidgetPlaybackConfig) -> String {
        return "var widget = \(config.widgetInit.constructor)('\(self.iframeId)');"
    }

    private static func generateEventBindings(config: WidgetPlaybackConfig, postMessage: String) -> String {
        var lines: [String] = []

        for event in config.events {
            let constant = "\(config.eventBinding.constantPrefix).\(event.widgetEvent)"
            let argName = event.callbackArg ?? "data"

            if let actions = event.actions {
                let actionJS = actions.map { action in
                    self.generateReadyActionJS(action, postMessage: postMessage)
                }.joined(separator: "\n                    ")

                lines.append("""
                widget.\(config.eventBinding.method)(\(constant), function(\(argName)) {
                            \(actionJS)
                        });
                """)
            } else if let post = event.post {
                let messageJS = self.generatePostMessageJS(post, argName: argName, postMessage: postMessage)
                lines.append("""
                widget.\(config.eventBinding.method)(\(constant), function(\(argName)) {
                            \(postMessage)(\(messageJS));
                        });
                """)
            }
        }

        return lines.joined(separator: "\n        ")
    }

    private static func generateReadyActionJS(_ action: ReadyAction, postMessage: String) -> String {
        switch action {
        case let .command(name):
            return "widget.\(name)();"
        case let .asyncMethod(method, post):
            let messageJS = self.generatePostMessageJS(post, argName: "_cbVal", postMessage: postMessage)
            return "widget.\(method)(function(_cbVal) { \(postMessage)(\(messageJS)); });"
        }
    }

    private static func generatePostMessageJS(_ post: PostMessage, argName: String, postMessage: String) -> String {
        var parts = ["type: '\(self.escapeJSString(post.type))'"]

        if let fields = post.fields {
            for (key, value) in fields.sorted(by: { $0.key < $1.key }) {
                let valueJS = self.generateValueJS(value, argName: argName)
                parts.append("\(key): \(valueJS)")
            }
        }

        return "{\(parts.joined(separator: ", "))}"
    }

    private static func generateValueJS(_ value: PostMessageValue, argName: String) -> String {
        switch value {
        case let .fieldExtraction(field, transform):
            var expr = "\(argName).\(field)"
            expr = self.applyTransforms(expr, transforms: transform, argName: argName)
            return expr

        case let .callbackArgRef(_, transform):
            var expr = argName
            expr = self.applyTransforms(expr, transforms: transform, argName: argName)
            return expr
        }
    }

    private static func applyTransforms(_ expr: String, transforms: [ValueTransform]?, argName: String) -> String {
        guard let transforms, !transforms.isEmpty else { return expr }

        var result = expr
        for transform in transforms {
            switch transform {
            case let .divide(divisor):
                result = "(\(result)) / \(self.formatNumber(divisor))"
            case let .multiply(multiplier):
                result = "(\(result)) * \(self.formatNumber(multiplier))"
            case let .divideByField(field):
                result = "(\(result)) / \(argName).\(field)"
            case .round:
                result = "Math.round(\(result))"
            }
        }
        return result
    }

    private static func generateCommands(config: WidgetPlaybackConfig) -> String {
        let playMethod = config.commands.play.method
        let pauseMethod = config.commands.pause.method
        let seekMethod = config.commands.seek.method

        return """
        function playerPlay() { widget.\(playMethod)(); }
                function playerPause() { widget.\(pauseMethod)(); }
                function playerSeek(ms) { widget.\(seekMethod)(ms); }
        """
    }

    private static func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func escapeJSString(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
    }

    private static func formatNumber(_ value: Double) -> String {
        if value == value.rounded() && value < 1_000_000 {
            return String(Int(value))
        }
        return String(value)
    }
}
