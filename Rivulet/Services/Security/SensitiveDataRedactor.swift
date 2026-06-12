//
//  SensitiveDataRedactor.swift
//  Rivulet
//

import Foundation

enum SensitiveDataRedactor {
    nonisolated static let redactedValue = "[REDACTED]"
    nonisolated static let redactedURLValue = "[REDACTED_URL]"

    private nonisolated static let queryRedactionValue = "REDACTED"

    private nonisolated static let sensitiveKeyNames: Set<String> = [
        "authorization",
        "xplextoken",
        "token",
        "authtoken",
        "accesstoken",
        "servertoken",
        "selectedservertoken",
        "homeusertoken",
        "credential",
        "credentials",
        "password",
        "pin",
        "streamurl",
        "streamuri"
    ]

    nonisolated static func redact(_ value: String?) -> String? {
        guard let value else { return nil }
        guard !value.isEmpty else { return "" }
        guard value != redactedValue, value != redactedURLValue else { return value }

        if looksLikeURL(value), let url = URL(string: value) {
            return redact(url)
        }

        return redactSensitiveFragments(in: value)
    }

    nonisolated static func redact(_ url: URL?) -> String? {
        guard let url else { return nil }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return redact(url.absoluteString)
        }
        return redact(components)
    }

    nonisolated static func redact(_ components: URLComponents?) -> String? {
        guard var components else { return nil }

        if components.user != nil {
            components.user = queryRedactionValue
        }
        if components.password != nil {
            components.password = queryRedactionValue
        }

        if let queryItems = components.queryItems {
            components.queryItems = queryItems.map { item in
                guard isSensitiveKey(item.name) else { return item }
                return URLQueryItem(name: item.name, value: queryRedactionValue)
            }
        }

        guard let rendered = components.string else { return nil }
        return redactSensitiveFragments(in: rendered)
    }

    nonisolated static func redact(metadata: [String: Any]) -> [String: Any] {
        metadata.reduce(into: [:]) { result, entry in
            result[entry.key] = redact(entry.value, forKey: entry.key)
        }
    }

    nonisolated static func redact(headers: [String: String]) -> [String: String] {
        headers.reduce(into: [:]) { result, entry in
            if isSensitiveKey(entry.key) {
                result[entry.key] = redactedValue
            } else {
                result[entry.key] = redact(entry.value)
            }
        }
    }

    private nonisolated static func redact(_ value: Any, forKey key: String?) -> Any {
        if let key, isSensitiveKey(key) {
            return replacementValue(forSensitiveKey: key)
        }

        switch value {
        case let string as String:
            return redact(string) ?? ""
        case let url as URL:
            return redact(url) ?? redactedURLValue
        case let components as URLComponents:
            return redact(components) ?? redactedURLValue
        case let dictionary as [String: Any]:
            return redact(metadata: dictionary)
        case let dictionary as NSDictionary:
            var redacted: [String: Any] = [:]
            dictionary.forEach { key, value in
                guard let key = key as? String else { return }
                redacted[key] = redact(value, forKey: key)
            }
            return redacted
        case let array as [Any]:
            return array.map { redact($0, forKey: nil) }
        default:
            return value
        }
    }

    private nonisolated static func replacementValue(forSensitiveKey key: String) -> String {
        let normalized = normalize(key)
        if normalized.contains("url") || normalized.contains("uri") {
            return redactedURLValue
        }
        return redactedValue
    }

    private nonisolated static func looksLikeURL(_ value: String) -> Bool {
        value.contains("://")
    }

    private nonisolated static func isSensitiveKey(_ key: String) -> Bool {
        let normalized = normalize(key)
        return sensitiveKeyNames.contains(normalized)
            || normalized == "url"
            || normalized == "uri"
            || normalized.hasSuffix("url")
            || normalized.hasSuffix("uri")
            || normalized.hasSuffix("token")
            || normalized.contains("credential")
            || normalized.contains("password")
            || normalized == "pin"
    }

    private nonisolated static func normalize(_ key: String) -> String {
        key
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
    }

    private nonisolated static func redactSensitiveFragments(in value: String) -> String {
        var redacted = value
        redacted = replaceMatches(
            in: redacted,
            pattern: #"(?i)(Authorization\s*[:=]\s*)(Bearer\s+)?[^&\s,;]+"#,
            template: "$1\(queryRedactionValue)"
        )
        redacted = replaceMatches(
            in: redacted,
            pattern: #"(?i)((?:X-Plex-Token|authToken|accessToken|serverToken|selectedServerToken|homeUserToken|token|pin|password|credentials?)\s*[:=]\s*)[^&\s,;]+"#,
            template: "$1\(queryRedactionValue)"
        )
        redacted = replaceMatches(
            in: redacted,
            pattern: #"(?i)((?:stream_url|streamURL|streamUrl|stream_uri|streamURI|streamUri)\s*[:=]\s*)[^&\s,;]+"#,
            template: "$1\(redactedURLValue)"
        )
        return redacted
    }

    private nonisolated static func replaceMatches(in value: String, pattern: String, template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return value }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return regex.stringByReplacingMatches(in: value, range: range, withTemplate: template)
    }
}
