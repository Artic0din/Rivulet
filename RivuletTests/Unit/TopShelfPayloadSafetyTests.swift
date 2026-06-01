//
//  TopShelfPayloadSafetyTests.swift
//  RivuletTests
//
//  E2-PR2 — proves the Top Shelf App Group payload is secret-free: no Plex
//  token, no token-bearing image URL, no stream URL. The token is confined to
//  the transient in-app fetch URL on `TopShelfDraft` and never reaches the
//  persisted `TopShelfItem`. Also covers migration safety from the old
//  token-bearing `imageURL` payload and deep-link field safety.
//

import XCTest
@testable import Rivulet

final class TopShelfPayloadSafetyTests: XCTestCase {

    private let secretToken = "SUPERSECRETTOKEN123"

    private func makeMetadata(type: String = "movie") throws -> PlexMetadata {
        let json = """
        {
            "ratingKey": "123",
            "title": "Test Movie",
            "type": "\(type)",
            "thumb": "/library/metadata/123/thumb/1700000000",
            "grandparentThumb": "/library/metadata/9/thumb/1700000000",
            "grandparentTitle": "Test Show",
            "lastViewedAt": 1700000000
        }
        """.data(using: .utf8)!
        return try JSONDecoder().decode(PlexMetadata.self, from: json)
    }

    // MARK: - Token isolation

    func testDraftCarriesTokenOnlyInTransientFetchURL() throws {
        let metadata = try makeMetadata()
        let draft = try XCTUnwrap(TopShelfPayloadBuilder.draft(
            from: metadata,
            serverIdentifier: "https://192.168.1.10:32400",
            serverURL: "https://192.168.1.10:32400",
            token: secretToken
        ))
        // The transient fetch URL is allowed to carry the token (in-app use only).
        let fetchURL = try XCTUnwrap(draft.authenticatedThumbURL)
        XCTAssertTrue(fetchURL.absoluteString.contains("X-Plex-Token=\(secretToken)"))
    }

    func testPersistedItemContainsNoTokenOrImageURLField() throws {
        let metadata = try makeMetadata()
        let draft = try XCTUnwrap(TopShelfPayloadBuilder.draft(
            from: metadata,
            serverIdentifier: "https://192.168.1.10:32400",
            serverURL: "https://192.168.1.10:32400",
            token: secretToken
        ))
        let item = TopShelfItem(draft: draft, imageFileName: "123.jpg")

        let data = try JSONEncoder().encode(item)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))

        XCTAssertFalse(json.contains(secretToken), "payload leaked the token")
        XCTAssertFalse(json.contains("X-Plex-Token"), "payload leaked a token query")
        XCTAssertFalse(json.contains("imageURL"), "payload still carries a remote image URL field")
        XCTAssertEqual(item.imageFileName, "123.jpg")
        // Preserved metadata.
        XCTAssertEqual(item.ratingKey, "123")
        XCTAssertEqual(item.title, "Test Movie")
        XCTAssertEqual(item.subtitle, "Test Show")
        XCTAssertEqual(item.type, "movie")
    }

    func testWholePayloadEncodesSecretFree() throws {
        let metadata = try makeMetadata()
        let draft = try XCTUnwrap(TopShelfPayloadBuilder.draft(
            from: metadata, serverIdentifier: "srv", serverURL: "https://s:32400", token: secretToken
        ))
        let items = [TopShelfItem(draft: draft, imageFileName: "123.jpg")]
        let data = try JSONEncoder().encode(items)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertFalse(json.contains(secretToken))
        XCTAssertFalse(json.contains("X-Plex-Token"))
    }

    // MARK: - imageFileName is a bare filename, never a URL

    func testImageFileNameIsOpaqueLeafName() throws {
        let item = TopShelfItem(
            draft: try XCTUnwrap(TopShelfPayloadBuilder.draft(
                from: try makeMetadata(), serverIdentifier: "srv", serverURL: "https://s:32400", token: secretToken
            )),
            imageFileName: "123.jpg"
        )
        let name = try XCTUnwrap(item.imageFileName)
        XCTAssertFalse(name.contains("http"))
        XCTAssertFalse(name.contains("://"))
        XCTAssertFalse(name.contains("?"))
        XCTAssertFalse(name.contains("/"))
        XCTAssertFalse(name.contains("X-Plex-Token"))
    }

    func testNilImageFileNameIsAllowedForFallback() throws {
        let item = TopShelfItem(
            draft: try XCTUnwrap(TopShelfPayloadBuilder.draft(
                from: try makeMetadata(), serverIdentifier: "srv", serverURL: "https://s:32400", token: secretToken
            )),
            imageFileName: nil
        )
        XCTAssertNil(item.imageFileName)
        // Round-trips cleanly so the extension can render the item without art.
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(TopShelfItem.self, from: data)
        XCTAssertNil(decoded.imageFileName)
    }

    // MARK: - Migration safety from the old token-bearing payload

    func testLegacyTokenBearingPayloadDecodesAsImagelessAndReencodesSecretFree() throws {
        // Payload shape written by pre-E2-PR2 builds: includes token-bearing
        // `imageURL`, no `imageFileName`.
        let legacy = """
        [{
            "ratingKey": "123",
            "title": "Old Movie",
            "subtitle": null,
            "imageURL": "https://192.168.1.10:32400/library/metadata/123/thumb/1?X-Plex-Token=\(secretToken)",
            "progress": 0.5,
            "type": "movie",
            "lastWatched": "2026-01-01T00:00:00Z",
            "serverIdentifier": "https://192.168.1.10:32400"
        }]
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let items = try decoder.decode([TopShelfItem].self, from: legacy)

        XCTAssertEqual(items.count, 1)
        XCTAssertNil(items[0].imageFileName, "legacy token URL must not survive as an image reference")
        XCTAssertEqual(items[0].title, "Old Movie")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let reencoded = try XCTUnwrap(String(data: try encoder.encode(items), encoding: .utf8))
        XCTAssertFalse(reencoded.contains(secretToken))
        XCTAssertFalse(reencoded.contains("X-Plex-Token"))
        XCTAssertFalse(reencoded.contains("imageURL"))
    }

    // MARK: - Transient URL construction

    func testAuthenticatedThumbURLAppendsTokenToRelativePath() throws {
        let url = try XCTUnwrap(TopShelfPayloadBuilder.authenticatedThumbURL(
            thumbPath: "/library/metadata/1/thumb/2", serverURL: "https://s:32400", token: "T"
        ))
        XCTAssertEqual(url.scheme, "https")
        XCTAssertTrue(url.absoluteString.hasPrefix("https://s:32400/library/metadata/1/thumb/2"))
        XCTAssertTrue(url.absoluteString.contains("X-Plex-Token=T"))
    }

    func testAuthenticatedThumbURLAppendsTokenToAbsoluteURL() throws {
        let url = try XCTUnwrap(TopShelfPayloadBuilder.authenticatedThumbURL(
            thumbPath: "https://cdn.example/x.jpg", serverURL: "https://s:32400", token: "T"
        ))
        XCTAssertTrue(url.absoluteString.hasPrefix("https://cdn.example/x.jpg"))
        XCTAssertTrue(url.absoluteString.contains("X-Plex-Token=T"))
    }

    func testAuthenticatedThumbURLNilWhenNoThumbOrToken() {
        XCTAssertNil(TopShelfPayloadBuilder.authenticatedThumbURL(thumbPath: "", serverURL: "https://s:32400", token: "T"))
        XCTAssertNil(TopShelfPayloadBuilder.authenticatedThumbURL(thumbPath: "/x", serverURL: "https://s:32400", token: ""))
    }

    // MARK: - Deep-link field safety

    func testDeepLinkFieldsAreSecretFree() throws {
        let metadata = try makeMetadata()
        let draft = try XCTUnwrap(TopShelfPayloadBuilder.draft(
            from: metadata, serverIdentifier: "https://192.168.1.10:32400", serverURL: "https://192.168.1.10:32400", token: secretToken
        ))
        // ratingKey + serverIdentifier are the only fields used to build the
        // rivulet:// deep link. Neither may contain a token.
        XCTAssertFalse(draft.ratingKey.contains("X-Plex-Token"))
        XCTAssertFalse(draft.ratingKey.contains(secretToken))
        XCTAssertFalse(draft.serverIdentifier.contains("X-Plex-Token"))
        XCTAssertFalse(draft.serverIdentifier.contains(secretToken))
    }
}
