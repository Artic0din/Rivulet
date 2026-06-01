//
//  HomeErrorPresentationTests.swift
//  RivuletTests
//
//  E2-PR7 — Home error copy is calm and never leaks tokens/URLs.
//

import XCTest
@testable import Rivulet

final class HomeErrorPresentationTests: XCTestCase {

    private let generic = HomeErrorPresentation.genericMessage

    // MARK: - Missing / empty

    func testNilFallsBackToGeneric() {
        XCTAssertEqual(HomeErrorPresentation.userFacingMessage(for: nil), generic)
    }

    func testEmptyFallsBackToGeneric() {
        XCTAssertEqual(HomeErrorPresentation.userFacingMessage(for: ""), generic)
        XCTAssertEqual(HomeErrorPresentation.userFacingMessage(for: "   \n "), generic)
    }

    // MARK: - Clean, user-facing messages pass through

    func testOfflineMessagePreserved() {
        let msg = "The Internet connection appears to be offline."
        XCTAssertEqual(HomeErrorPresentation.userFacingMessage(for: msg), msg)
    }

    func testTimeoutMessagePreserved() {
        let msg = "The request timed out."
        XCTAssertEqual(HomeErrorPresentation.userFacingMessage(for: msg), msg)
    }

    func testControlledConnectionCopyPreserved() {
        let msg = "Could not connect to server. Check your network."
        XCTAssertEqual(HomeErrorPresentation.userFacingMessage(for: msg), msg)
    }

    // MARK: - Technical / secret-bearing strings are replaced

    func testTokenBearingURLNeverLeaks() {
        let raw = "Failed to load https://plex.example.com:32400/hubs?X-Plex-Token=abcd1234secret"
        let out = HomeErrorPresentation.userFacingMessage(for: raw)
        XCTAssertEqual(out, generic)
        XCTAssertFalse(out.contains("abcd1234secret"))
        XCTAssertFalse(out.contains("://"))
        XCTAssertFalse(out.lowercased().contains("x-plex-token"))
    }

    func testNSErrorDumpReplaced() {
        let raw = "Error Domain=NSURLErrorDomain Code=-1009 \"The operation couldn’t be completed.\""
        XCTAssertEqual(HomeErrorPresentation.userFacingMessage(for: raw), generic)
    }

    func testBareTokenFragmentNeverLeaks() {
        let raw = "request rejected (authToken=topsecretvalue)"
        let out = HomeErrorPresentation.userFacingMessage(for: raw)
        XCTAssertEqual(out, generic)
        XCTAssertFalse(out.contains("topsecretvalue"))
    }

    func testRawURLWithoutTokenStillReplaced() {
        // Even a token-free URL is not appropriate user-facing copy.
        let raw = "GET https://plex.example.com/library/sections failed"
        XCTAssertEqual(HomeErrorPresentation.userFacingMessage(for: raw), generic)
    }

    // MARK: - looksTechnical

    func testLooksTechnicalFlags() {
        XCTAssertTrue(HomeErrorPresentation.looksTechnical("scheme://host"))
        XCTAssertTrue(HomeErrorPresentation.looksTechnical("Error Domain=Foo Code=1"))
        XCTAssertTrue(HomeErrorPresentation.looksTechnical("value=[REDACTED]"))
        XCTAssertFalse(HomeErrorPresentation.looksTechnical("Your library is empty."))
    }
}
