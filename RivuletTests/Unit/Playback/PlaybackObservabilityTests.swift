//
//  PlaybackObservabilityTests.swift
//  RivuletTests
//
//  E4-PR1 — playback observability regression guards. Proves the invariants the
//  playback diagnostics rely on so a token-bearing stream URL can never reach a
//  log/Sentry sink: `lastPathComponent` strips token/host/query (the transform
//  the FFmpegDemuxer URLSession-AVIO log uses), `SensitiveDataRedactor` strips
//  the token from a full URL and is idempotent, and the HLS manifest diagnostic
//  summary emits neither token nor URL.
//

import XCTest
@testable import Rivulet

final class PlaybackObservabilityTests: XCTestCase {

    private let token = "SECRETTOKEN123"
    private let directPartURL =
        "http://10.0.0.5:32400/library/parts/123/456/file.mkv?X-Plex-Token=SECRETTOKEN123&download=1"
    private let transcodeManifestURL =
        "http://10.0.0.5:32400/video/:/transcode/universal/start.m3u8?X-Plex-Token=SECRETTOKEN123&session=abc"

    // MARK: - lastPathComponent diagnostic transform (FFmpegDemuxer log)

    func testLastPathComponentDropsTokenHostAndQueryForDirectPart() throws {
        let url = try XCTUnwrap(URL(string: directPartURL))
        let component = url.lastPathComponent
        XCTAssertEqual(component, "file.mkv")
        XCTAssertFalse(component.contains("X-Plex-Token"))
        XCTAssertFalse(component.contains(token))
        XCTAssertFalse(component.contains("10.0.0.5"))
    }

    func testLastPathComponentDropsTokenForTranscodeManifest() throws {
        let url = try XCTUnwrap(URL(string: transcodeManifestURL))
        XCTAssertEqual(url.lastPathComponent, "start.m3u8")
        XCTAssertFalse(url.lastPathComponent.contains(token))
    }

    // MARK: - Redactor is the safe sink for full-URL diagnostics, and idempotent

    func testRedactorStripsTokenFromStreamURL() throws {
        let url = try XCTUnwrap(URL(string: directPartURL))
        let redacted = try XCTUnwrap(SensitiveDataRedactor.redact(url))
        XCTAssertFalse(redacted.contains(token))
    }

    func testRedactionIsIdempotent() throws {
        let url = try XCTUnwrap(URL(string: transcodeManifestURL))
        let once = try XCTUnwrap(SensitiveDataRedactor.redact(url))
        let twice = try XCTUnwrap(SensitiveDataRedactor.redact(once))
        XCTAssertEqual(once, twice)
        XCTAssertFalse(twice.contains(token))
    }

    func testRedactedURLValueSentinel() {
        XCTAssertEqual(SensitiveDataRedactor.redactedURLValue, "[REDACTED_URL]")
    }

    // MARK: - HLS manifest diagnostic summary leaks neither token nor URL

    func testHLSManifestSummaryEmitsNoTokenOrURL() {
        let manifest = """
        #EXTM3U
        #EXT-X-STREAM-INF:BANDWIDTH=1
        http://10.0.0.5:32400/seg.ts?X-Plex-Token=SECRETTOKEN123
        """
        let summary = HLSManifestEnricher.manifestDiagnosticSummary(manifest)
        XCTAssertFalse(summary.contains(token))
        XCTAssertFalse(summary.contains("http"))
        XCTAssertFalse(summary.contains("X-Plex-Token"))
    }
}
