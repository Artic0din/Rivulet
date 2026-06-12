//
//  PlaybackTelemetryTests.swift
//  RivuletTests
//
//  E4-PR2 — proves the playback telemetry contract is safe by construction:
//  payloads contain only allow-listed fields and can never carry a token or
//  stream URL, even when a caller passes a hostile free-text value.
//

import XCTest
@testable import Rivulet

final class PlaybackTelemetryTests: XCTestCase {

    private let token = "SECRETTOKEN123"
    private let tokenURL = "http://10.0.0.5:32400/video/:/transcode/start.m3u8?X-Plex-Token=SECRETTOKEN123"

    /// The complete set of keys the contract is permitted to emit.
    private let allowedKeys: Set<String> = [
        "media_type", "rating_key", "codec", "container", "audio", "subtitle",
        "mode", "startup_ms", "failure", "route", "reason", "from", "to",
        "rebuffer_count", "recovery"
    ]

    private func assertNoSecret(_ fields: [String: String], file: StaticString = #filePath, line: UInt = #line) {
        for (k, v) in fields {
            let lower = v.lowercased()
            XCTAssertFalse(v.contains(token), "value for \(k) leaked token value", file: file, line: line)
            XCTAssertFalse(lower.contains("http"), "value for \(k) leaked URL scheme", file: file, line: line)
            XCTAssertFalse(lower.contains("://"), "value for \(k) leaked URL", file: file, line: line)
            XCTAssertFalse(v.contains("10.0.0.5"), "value for \(k) leaked host/IP", file: file, line: line)
        }
    }

    private func assertAllowedKeys(_ fields: [String: String], file: StaticString = #filePath, line: UInt = #line) {
        for k in fields.keys {
            XCTAssertTrue(allowedKeys.contains(k), "disallowed key \(k)", file: file, line: line)
        }
    }

    // MARK: - Hostile free-text reason is scrubbed

    func testRouteSelectedReasonWithTokenURLIsRedacted() {
        let ctx = PlaybackTelemetry.SafeContext(mediaType: "movie", ratingKey: "12345")
        let fields = PlaybackTelemetry.fields(for: .routeSelected(ctx, route: .hls, reason: "fallback to \(tokenURL)"))
        assertAllowedKeys(fields)
        assertNoSecret(fields)
        XCTAssertEqual(fields["route"], "hls")
    }

    // MARK: - Hostile SafeContext values are scrubbed

    func testSafeContextValuesAreRedacted() {
        let ctx = PlaybackTelemetry.SafeContext(
            mediaType: "episode",
            ratingKey: tokenURL,             // hostile
            codecFamily: "X-Plex-Token=\(token)" // hostile
        )
        let fields = PlaybackTelemetry.fields(for: .startupBegan(ctx, mode: .directPlay))
        assertAllowedKeys(fields)
        assertNoSecret(fields)
    }

    // MARK: - Allow-list holds across every event

    func testAllEventsEmitOnlyAllowedKeysAndNoSecrets() {
        let ctx = PlaybackTelemetry.SafeContext(
            mediaType: "movie", ratingKey: "999", codecFamily: "hevc",
            containerFamily: "mkv", audioFamily: "truehd", subtitleType: "pgs"
        )
        let events: [PlaybackTelemetry.Event] = [
            .startupBegan(ctx, mode: .transcode),
            .startupCompleted(ctx, mode: .directPlay, durationMs: 1234),
            .startupFailed(ctx, category: .network),
            .routeSelected(ctx, route: .avPlayerDirect, reason: "native mp4"),
            .routeFellBack(ctx, from: .avPlayerDirect, to: .hls, category: .decode),
            .rebuffer(ctx, count: 3),
            .stall(ctx),
            .recovered(ctx, result: .fellBack)
        ]
        for event in events {
            let fields = PlaybackTelemetry.fields(for: event)
            assertAllowedKeys(fields)
            assertNoSecret(fields)
        }
    }

    // MARK: - Categories / outcomes preserved without detail

    func testFailureCategoryPreserved() {
        let fields = PlaybackTelemetry.fields(for: .startupFailed(.init(), category: .demux))
        XCTAssertEqual(fields["failure"], "demux")
    }

    func testFallbackFieldsPreserved() {
        let fields = PlaybackTelemetry.fields(for: .routeFellBack(.init(), from: .rplayerDirectPlay, to: .hls, category: .decode))
        XCTAssertEqual(fields["from"], "rplayerDirectPlay")
        XCTAssertEqual(fields["to"], "hls")
        XCTAssertEqual(fields["failure"], "decode")
    }

    func testStartupDurationAndRebufferAreNonNegative() {
        XCTAssertEqual(PlaybackTelemetry.fields(for: .startupCompleted(.init(), mode: .directPlay, durationMs: -5))["startup_ms"], "0")
        XCTAssertEqual(PlaybackTelemetry.fields(for: .rebuffer(.init(), count: -2))["rebuffer_count"], "0")
    }

    // MARK: - Deterministic + idempotent

    func testFieldsAreDeterministic() {
        let ctx = PlaybackTelemetry.SafeContext(mediaType: "movie", codecFamily: "hevc")
        let a = PlaybackTelemetry.fields(for: .routeSelected(ctx, route: .hls, reason: "x"))
        let b = PlaybackTelemetry.fields(for: .routeSelected(ctx, route: .hls, reason: "x"))
        XCTAssertEqual(a, b)
    }

    func testRedactionIdempotentOnValues() {
        // Re-feeding an already-clean value yields no change (redaction stable).
        let ctx = PlaybackTelemetry.SafeContext(ratingKey: tokenURL)
        let once = PlaybackTelemetry.fields(for: .stall(ctx))["rating_key"]
        let twiceCtx = PlaybackTelemetry.SafeContext(ratingKey: once)
        let twice = PlaybackTelemetry.fields(for: .stall(twiceCtx))["rating_key"]
        XCTAssertEqual(once, twice)
        XCTAssertNotNil(once)
        XCTAssertFalse(once!.contains(token))
    }

    // MARK: - Names are stable

    func testEventNamesStable() {
        XCTAssertEqual(PlaybackTelemetry.name(for: .stall(.init())), "playback.stall")
        XCTAssertEqual(PlaybackTelemetry.name(for: .routeSelected(.init(), route: .hls, reason: "")), "playback.route.selected")
    }
}
