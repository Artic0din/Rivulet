//
//  PlaybackTelemetry.swift
//  Rivulet
//
//  E4-PR2 — the safe playback telemetry contract.
//
//  Telemetry is SAFE BY CONSTRUCTION: the public API accepts only typed `Event`
//  cases whose fields are an allow-list of non-sensitive descriptors. There is no
//  `URL` parameter and no free-form dictionary anywhere in the public surface, so
//  a Plex token, stream URL, manifest URL, auth header, or raw error body simply
//  cannot be passed in. As defense-in-depth, every string value is additionally
//  run through `SensitiveDataRedactor` at the sink boundary (idempotent), so even
//  a free-text `reason` that accidentally embedded a URL would be scrubbed.
//
//  Sinks (no third-party analytics beyond the existing Sentry):
//   - `os_signpost` event — carries ONLY the typed event name (no field values).
//   - a redacted Sentry breadcrumb — `data` is the allow-listed field dictionary.
//
//  This slice DEFINES and TESTS the contract. Instrumentation of the live events
//  is adopted by the slices that own those events (route/fallback → E4-PR3 routing
//  policies, where the route is a typed value; rebuffer/stall/recovery → E4-PR5).
//  Future Epic 4 code MUST emit playback telemetry only through this type.
//

import Foundation
import os
import Sentry

nonisolated enum PlaybackTelemetry {

    // MARK: - Typed vocabularies (no raw URLs/tokens can be expressed)

    /// Anonymised route name (never a URL).
    enum RouteName: String, Sendable {
        case avPlayerDirect, localRemux, hls, rplayerDirectPlay, unknown
    }

    /// Playback mode family.
    enum PlaybackMode: String, Sendable {
        case directPlay, directStream, transcode, unknown
    }

    /// Failure category — preserves the *kind* of failure without any detail that
    /// could carry a URL/token/raw error body.
    enum FailureCategory: String, Sendable {
        case startup, network, decode, transcode, demux, unsupported, unknown
    }

    /// Outcome of a recovery attempt.
    enum RecoveryResult: String, Sendable {
        case recovered, fellBack, failed
    }

    /// Allow-listed, non-sensitive descriptors of *what* is playing. Every field
    /// is optional and free of secrets (rating key is a Plex identifier, not a
    /// credential; codec/container/audio/subtitle are format families).
    struct SafeContext: Sendable {
        var mediaType: String?
        var ratingKey: String?
        var codecFamily: String?
        var containerFamily: String?
        var audioFamily: String?
        var subtitleType: String?

        init(
            mediaType: String? = nil,
            ratingKey: String? = nil,
            codecFamily: String? = nil,
            containerFamily: String? = nil,
            audioFamily: String? = nil,
            subtitleType: String? = nil
        ) {
            self.mediaType = mediaType
            self.ratingKey = ratingKey
            self.codecFamily = codecFamily
            self.containerFamily = containerFamily
            self.audioFamily = audioFamily
            self.subtitleType = subtitleType
        }
    }

    /// The typed event set (intentionally small — the high-value Epic 4 events).
    enum Event: Sendable {
        case startupBegan(SafeContext, mode: PlaybackMode)
        case startupCompleted(SafeContext, mode: PlaybackMode, durationMs: Int)
        case startupFailed(SafeContext, category: FailureCategory)
        case routeSelected(SafeContext, route: RouteName, reason: String)
        case routeFellBack(SafeContext, from: RouteName, to: RouteName, category: FailureCategory)
        case rebuffer(SafeContext, count: Int)
        case stall(SafeContext)
        case recovered(SafeContext, result: RecoveryResult)
    }

    // MARK: - Pure builders (unit-tested seams)

    /// Stable, typed event name (also the signpost / breadcrumb message).
    static func name(for event: Event) -> String {
        switch event {
        case .startupBegan:     return "playback.startup.began"
        case .startupCompleted: return "playback.startup.completed"
        case .startupFailed:    return "playback.startup.failed"
        case .routeSelected:    return "playback.route.selected"
        case .routeFellBack:    return "playback.route.fellback"
        case .rebuffer:         return "playback.rebuffer"
        case .stall:            return "playback.stall"
        case .recovered:        return "playback.recovered"
        }
    }

    /// The allow-listed breadcrumb field dictionary for an event. ONLY safe keys
    /// appear, and every value is passed through `SensitiveDataRedactor` (so an
    /// accidentally-URL-bearing free-text value is scrubbed). Pure + deterministic.
    static func fields(for event: Event) -> [String: String] {
        switch event {
        case let .startupBegan(ctx, mode):
            return base(ctx).merging(["mode": mode.rawValue], uniquingKeysWith: { a, _ in a })
        case let .startupCompleted(ctx, mode, durationMs):
            return base(ctx).merging([
                "mode": mode.rawValue,
                "startup_ms": String(max(0, durationMs))
            ], uniquingKeysWith: { a, _ in a })
        case let .startupFailed(ctx, category):
            return base(ctx).merging(["failure": category.rawValue], uniquingKeysWith: { a, _ in a })
        case let .routeSelected(ctx, route, reason):
            return base(ctx).merging([
                "route": route.rawValue,
                "reason": safe(reason)
            ], uniquingKeysWith: { a, _ in a })
        case let .routeFellBack(ctx, from, to, category):
            return base(ctx).merging([
                "from": from.rawValue,
                "to": to.rawValue,
                "failure": category.rawValue
            ], uniquingKeysWith: { a, _ in a })
        case let .rebuffer(ctx, count):
            return base(ctx).merging(["rebuffer_count": String(max(0, count))], uniquingKeysWith: { a, _ in a })
        case let .stall(ctx):
            return base(ctx)
        case let .recovered(ctx, result):
            return base(ctx).merging(["recovery": result.rawValue], uniquingKeysWith: { a, _ in a })
        }
    }

    /// SafeContext → redacted, non-nil field pairs.
    private static func base(_ ctx: SafeContext) -> [String: String] {
        var out: [String: String] = [:]
        if let v = ctx.mediaType { out["media_type"] = safe(v) }
        if let v = ctx.ratingKey { out["rating_key"] = safe(v) }
        if let v = ctx.codecFamily { out["codec"] = safe(v) }
        if let v = ctx.containerFamily { out["container"] = safe(v) }
        if let v = ctx.audioFamily { out["audio"] = safe(v) }
        if let v = ctx.subtitleType { out["subtitle"] = safe(v) }
        return out
    }

    /// Boundary redaction (idempotent). Any whole URL embedded in a free-text
    /// value is replaced with the `[REDACTED_URL]` sentinel FIRST — token-only
    /// redaction would still expose the scheme/host/IP/path, which the contract
    /// forbids — then remaining token fragments are scrubbed. Non-sensitive
    /// values (format families, identifiers) pass through unchanged.
    private static func safe(_ value: String) -> String {
        let urlStripped = value
            .split(separator: " ", omittingEmptySubsequences: false)
            .map { part -> Substring in
                let lower = part.lowercased()
                return (lower.contains("://") || lower.hasPrefix("http"))
                    ? Substring(SensitiveDataRedactor.redactedURLValue)
                    : part
            }
            .joined(separator: " ")
        return SensitiveDataRedactor.redact(urlStripped) ?? urlStripped
    }

    // MARK: - Emission (signpost event name only; redacted Sentry breadcrumb)

    private static let signposter = OSSignposter(
        subsystem: "com.rivulet.app",
        category: "PlaybackTelemetry"
    )

    static func emit(_ event: Event) {
        let eventName = name(for: event)

        // Signpost carries only the typed event name — no field values, so no
        // forbidden field can reach the signpost stream.
        signposter.emitEvent("PlaybackTelemetry", "\(eventName, privacy: .public)")

        // Sentry breadcrumb: allow-listed, redacted fields only.
        let crumb = Breadcrumb(level: .info, category: "playback.telemetry")
        crumb.message = eventName
        crumb.data = fields(for: event)
        SentrySDK.addBreadcrumb(crumb)
    }
}
