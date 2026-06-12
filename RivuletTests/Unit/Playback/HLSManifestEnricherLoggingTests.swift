//
//  HLSManifestEnricherLoggingTests.swift
//  RivuletTests
//
//  Security regression tests for the HLS manifest diagnostic path.
//
//  A simulator run leaked raw `X-Plex-Token=…` values because the enricher (and
//  the player view model) logged the patched manifest body line by line, and the
//  patched lines carry absolute Plex URLs with the token appended. The fix logs a
//  token-free structural SUMMARY instead. These tests pin that the summary seam
//  is safe by construction and that the approved redactor scrubs token-bearing
//  URLs before any fallback logging.
//

import XCTest
@testable import Rivulet

final class HLSManifestEnricherLoggingTests: XCTestCase {

    private let token = "abc123SECRETtoken"

    /// A patched master playlist as produced by `patchMasterPlaylist` — every
    /// variant/URI rewritten to an absolute Plex URL with the token appended.
    private func patchedManifestWithTokens() -> String {
        """
        #EXTM3U
        #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="Dolby Digital+ 5.1",LANGUAGE="en",CHANNELS="6",DEFAULT=YES,AUTOSELECT=YES
        #EXT-X-STREAM-INF:BANDWIDTH=8000000,AUDIO="audio"
        http://server:32400/video/:/transcode/universal/session/0/index.m3u8?X-Plex-Token=\(token)
        #EXT-X-I-FRAME-STREAM-INF:BANDWIDTH=200000,URI="http://server:32400/video/:/transcode/universal/session/0/iframe.m3u8?X-Plex-Token=\(token)"
        """
    }

    // MARK: - Summary is token-free by construction

    func testSummaryNeverContainsRawToken() {
        let summary = HLSManifestEnricher.manifestDiagnosticSummary(patchedManifestWithTokens())
        XCTAssertFalse(summary.contains("X-Plex-Token"), "summary leaked the token key")
        XCTAssertFalse(summary.contains(token), "summary leaked the token value")
    }

    func testSummaryEmitsNoURLBody() {
        let summary = HLSManifestEnricher.manifestDiagnosticSummary(patchedManifestWithTokens())
        // No URLs, no manifest tags, no segment lines — counts only.
        XCTAssertFalse(summary.contains("://"))
        XCTAssertFalse(summary.contains(".m3u8"))
        XCTAssertFalse(summary.contains("#EXT"))
    }

    func testSummaryReportsUsefulCounts() {
        let summary = HLSManifestEnricher.manifestDiagnosticSummary(patchedManifestWithTokens())
        // 5 non-empty lines, 1 variant, 1 media, 1 i-frame, 1 plain-URI ref.
        XCTAssertEqual(summary, "lines=5 variants=1 media=1 iFrame=1 uriRefs=1")
    }

    func testSummaryHandlesEmptyManifest() {
        XCTAssertEqual(
            HLSManifestEnricher.manifestDiagnosticSummary(""),
            "lines=0 variants=0 media=0 iFrame=0 uriRefs=0"
        )
    }

    // MARK: - Redactor scrubs token-bearing manifest lines (fallback paths)

    func testRedactorScrubsTokenInManifestLine() {
        let line = "http://server:32400/video/:/transcode/universal/index.m3u8?X-Plex-Token=\(token)"
        let redacted = SensitiveDataRedactor.redact(line) ?? ""
        XCTAssertFalse(redacted.contains(token))
        XCTAssertTrue(redacted.contains("X-Plex-Token=REDACTED") || !redacted.contains("X-Plex-Token"))
    }

    func testRedactionIsIdempotent() {
        let line = "stream open failed url=http://server:32400/start.m3u8?X-Plex-Token=\(token)"
        let once = SensitiveDataRedactor.redact(line) ?? ""
        let twice = SensitiveDataRedactor.redact(once) ?? ""
        XCTAssertEqual(once, twice, "redaction must be idempotent")
        XCTAssertFalse(twice.contains(token))
    }

    func testRedactedErrorStringCarriesNoToken() {
        // Mirrors the catch-path: an error whose description embeds a token URL.
        let errorLike = "Error: cannotConnect failingURL=http://server:32400/seg.ts?X-Plex-Token=\(token)"
        let safe = SensitiveDataRedactor.redact(String(describing: errorLike)) ?? "error"
        XCTAssertFalse(safe.contains(token))
    }
}
