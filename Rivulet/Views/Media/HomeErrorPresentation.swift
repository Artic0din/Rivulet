//
//  HomeErrorPresentation.swift
//  Rivulet
//
//  E2-PR7 — calm, safe user-facing copy for Home error states.
//
//  Several Home error surfaces are fed raw `error.localizedDescription`
//  (hub-load failures, recommendation failures) or upstream connection
//  strings. Surfacing those verbatim is both poor UX (technical NSError dumps)
//  and a privacy risk (a failing request's description can carry a
//  token-bearing URL). This maps any raw error string to calm copy that is
//  guaranteed never to contain a token, credential, or URL.
//
//  Pure and `nonisolated` so it is unit-testable and callable from any context.
//  This does not change error *detection* — only the human-readable message a
//  Home surface displays. Clean, already-user-facing messages (for example
//  "The Internet connection appears to be offline.") pass through unchanged;
//  technical or secret-bearing strings are replaced with a generic fallback.
//

import Foundation

nonisolated enum HomeErrorPresentation {

    /// Calm fallback used when the raw message is missing, technical, or could
    /// leak sensitive data.
    static let genericMessage = "Something went wrong loading your content. Please try again."

    /// Returns display-safe copy for a raw error string.
    ///
    /// - Empty/nil → the generic fallback.
    /// - Otherwise the string is first scrubbed of any token/credential/URL
    ///   fragments (`SensitiveDataRedactor`). If the scrubbed result still
    ///   reads as technical (a URL, an `NSError` domain/code dump, or a leftover
    ///   redaction marker), the generic fallback is used instead so the user
    ///   never sees raw diagnostics. Clean, human-readable messages are kept.
    static func userFacingMessage(for raw: String?) -> String {
        guard let raw else { return genericMessage }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return genericMessage }

        let sanitized = (SensitiveDataRedactor.redact(trimmed) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if sanitized.isEmpty || looksTechnical(sanitized) {
            return genericMessage
        }
        return sanitized
    }

    /// Heuristic: does this string read as a raw diagnostic rather than copy a
    /// user should see? Conservative — only flags clearly technical shapes.
    static func looksTechnical(_ value: String) -> Bool {
        let lower = value.lowercased()
        return value.contains("://")
            || lower.contains("error domain")
            || lower.contains("nsurlerror")
            || lower.contains("nscocoaerror")
            || lower.contains("code=")
            || lower.contains("redacted")
            || lower.contains("x-plex")
    }
}
