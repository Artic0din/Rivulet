//
//  SensitiveDataRedactorTests.swift
//  RivuletTests
//

import XCTest
@testable import Rivulet

final class SensitiveDataRedactorTests: XCTestCase {
    private let token = "secret-plex-token-123"

    func testRedactsQueryTokensInPlexMediaURL() {
        let rawURL = "https://server.example:32400/library/parts/42/file.mkv?X-Plex-Token=\(token)&offset=10"

        let redacted = SensitiveDataRedactor.redact(rawURL)

        XCTAssertFalse(redacted?.contains(token) ?? true)
        XCTAssertTrue(redacted?.contains("X-Plex-Token=REDACTED") ?? false)
        XCTAssertTrue(redacted?.contains("offset=10") ?? false)
    }

    func testRedactsHeaderTokens() {
        let metadata: [String: Any] = [
            "Authorization": "Bearer \(token)",
            "X-Plex-Token": token,
            "authToken": token,
            "accessToken": token
        ]
        let headers = [
            "Authorization": "Bearer \(token)",
            "X-Plex-Token": token,
            "X-Plex-Product": "Rivulet"
        ]

        let redacted = SensitiveDataRedactor.redact(metadata: metadata)
        let redactedHeaders = SensitiveDataRedactor.redact(headers: headers)

        XCTAssertEqual(redacted["Authorization"] as? String, SensitiveDataRedactor.redactedValue)
        XCTAssertEqual(redacted["X-Plex-Token"] as? String, SensitiveDataRedactor.redactedValue)
        XCTAssertEqual(redacted["authToken"] as? String, SensitiveDataRedactor.redactedValue)
        XCTAssertEqual(redacted["accessToken"] as? String, SensitiveDataRedactor.redactedValue)
        XCTAssertEqual(redactedHeaders["Authorization"], SensitiveDataRedactor.redactedValue)
        XCTAssertEqual(redactedHeaders["X-Plex-Token"], SensitiveDataRedactor.redactedValue)
        XCTAssertEqual(redactedHeaders["X-Plex-Product"], "Rivulet")
    }

    func testRedactsStreamURLMetadataValues() {
        let metadata: [String: Any] = [
            "stream_url": "https://server.example:32400/video/:/transcode/universal/start.m3u8?X-Plex-Token=\(token)",
            "component": "playback"
        ]

        let redacted = SensitiveDataRedactor.redact(metadata: metadata)

        XCTAssertEqual(redacted["stream_url"] as? String, SensitiveDataRedactor.redactedURLValue)
        XCTAssertEqual(redacted["component"] as? String, "playback")
    }

    func testRedactsNestedMetadataValues() {
        let metadata: [String: Any] = [
            "request": [
                "headers": [
                    "Authorization": "Bearer \(token)"
                ],
                "url": "https://discover.provider.plex.tv/actions/addToWatchlist?ratingKey=1&X-Plex-Token=\(token)"
            ],
            "events": [
                ["authToken": token],
                ["status": "safe"]
            ]
        ]

        let redacted = SensitiveDataRedactor.redact(metadata: metadata)
        let request = redacted["request"] as? [String: Any]
        let headers = request?["headers"] as? [String: Any]
        let events = redacted["events"] as? [[String: Any]]

        XCTAssertEqual(headers?["Authorization"] as? String, SensitiveDataRedactor.redactedValue)
        XCTAssertEqual(request?["url"] as? String, SensitiveDataRedactor.redactedURLValue)
        XCTAssertEqual(events?.first?["authToken"] as? String, SensitiveDataRedactor.redactedValue)
        XCTAssertEqual(events?.last?["status"] as? String, "safe")
    }

    func testKeepsSafeFieldsReadable() {
        let metadata: [String: Any] = [
            "component": "plex_network",
            "method": "GET",
            "status_code": 404,
            "media_type": "movie"
        ]

        let redacted = SensitiveDataRedactor.redact(metadata: metadata)

        XCTAssertEqual(redacted["component"] as? String, "plex_network")
        XCTAssertEqual(redacted["method"] as? String, "GET")
        XCTAssertEqual(redacted["status_code"] as? Int, 404)
        XCTAssertEqual(redacted["media_type"] as? String, "movie")
    }

    func testRedactionIsDeterministic() {
        let rawURL = "https://metadata.provider.plex.tv/library/metadata/matches?guid=tmdb://1&X-Plex-Token=\(token)"

        XCTAssertEqual(SensitiveDataRedactor.redact(rawURL), SensitiveDataRedactor.redact(rawURL))
    }

    func testRedactionIsIdempotent() {
        let rawURL = "https://server.example:32400/library/metadata/1?X-Plex-Token=\(token)"

        let once = SensitiveDataRedactor.redact(rawURL)
        let twice = SensitiveDataRedactor.redact(once)

        XCTAssertEqual(once, twice)
    }

    func testNilAndEmptyInputAreSafe() {
        XCTAssertNil(SensitiveDataRedactor.redact(nil as String?))
        XCTAssertNil(SensitiveDataRedactor.redact(nil as URL?))
        XCTAssertNil(SensitiveDataRedactor.redact(nil as URLComponents?))
        XCTAssertEqual(SensitiveDataRedactor.redact(""), "")
        XCTAssertTrue(SensitiveDataRedactor.redact(metadata: [:]).isEmpty)
    }

    func testKnownPlexTranscodeAndDecisionURLsAreHandled() {
        let transcode = URL(string: "https://server.example:32400/video/:/transcode/universal/start.m3u8?X-Plex-Token=\(token)&path=/library/metadata/123")
        let decision = URL(string: "https://server.example:32400/video/:/transcode/universal/decision?X-Plex-Token=\(token)&path=/library/metadata/123")

        XCTAssertFalse(SensitiveDataRedactor.redact(transcode)?.contains(token) ?? true)
        XCTAssertFalse(SensitiveDataRedactor.redact(decision)?.contains(token) ?? true)
        XCTAssertTrue(SensitiveDataRedactor.redact(transcode)?.contains("X-Plex-Token=REDACTED") ?? false)
        XCTAssertTrue(SensitiveDataRedactor.redact(decision)?.contains("X-Plex-Token=REDACTED") ?? false)
    }

    func testUserInfoCredentialsInURLsAreRedacted() {
        let playlist = URL(string: "https://user:password@example.com/playlist.m3u?token=\(token)")

        let redacted = SensitiveDataRedactor.redact(playlist)

        XCTAssertFalse(redacted?.contains("user") ?? true)
        XCTAssertFalse(redacted?.contains("password") ?? true)
        XCTAssertFalse(redacted?.contains(token) ?? true)
        XCTAssertTrue(redacted?.contains("https://REDACTED:REDACTED@example.com") ?? false)
        XCTAssertTrue(redacted?.contains("token=REDACTED") ?? false)
    }

    func testKnownDiscoverProviderURLsAreHandled() {
        let discover = URLComponents(string: "https://discover.provider.plex.tv/library/sections/watchlist/all?includeGuids=1&X-Plex-Token=\(token)")
        let metadata = URLComponents(string: "https://metadata.provider.plex.tv/library/metadata/matches?type=1&guid=tmdb://1&X-Plex-Token=\(token)")

        XCTAssertFalse(SensitiveDataRedactor.redact(discover)?.contains(token) ?? true)
        XCTAssertFalse(SensitiveDataRedactor.redact(metadata)?.contains(token) ?? true)
        XCTAssertTrue(SensitiveDataRedactor.redact(discover)?.contains("includeGuids=1") ?? false)
        XCTAssertTrue(SensitiveDataRedactor.redact(metadata)?.contains("guid=tmdb://1") ?? false)
    }
}
