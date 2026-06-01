//
//  MetadataBadgeTests.swift
//  RivuletTests
//
//  ADO-06 — RatingBadgePolicy display normalisation. Value/source are never
//  changed; only a locale prefix is stripped and whitespace trimmed for display.
//

import XCTest
@testable import Rivulet

final class RatingBadgePolicyTests: XCTestCase {

    func testStripsLeadingLocalePrefix() {
        XCTAssertEqual(RatingBadgePolicy.displayRating("US:TV-MA"), "TV-MA")
        XCTAssertEqual(RatingBadgePolicy.displayRating("de:16"), "16")
        XCTAssertEqual(RatingBadgePolicy.displayRating("au:MA15+"), "MA15+")
    }

    func testLeavesPlainRatingUnchanged() {
        XCTAssertEqual(RatingBadgePolicy.displayRating("TV-MA"), "TV-MA")
        XCTAssertEqual(RatingBadgePolicy.displayRating("PG-13"), "PG-13")
        XCTAssertEqual(RatingBadgePolicy.displayRating("M"), "M")
    }

    func testTrimsWhitespace() {
        XCTAssertEqual(RatingBadgePolicy.displayRating("  PG-13  "), "PG-13")
        XCTAssertEqual(RatingBadgePolicy.displayRating("US: TV-14"), "TV-14")
    }

    func testEmptyOrNilProducesNil() {
        XCTAssertNil(RatingBadgePolicy.displayRating(nil))
        XCTAssertNil(RatingBadgePolicy.displayRating(""))
        XCTAssertNil(RatingBadgePolicy.displayRating("   "))
    }

    func testDoesNotStripNonLocalePrefix() {
        // A three-letter or non-letter segment before ':' is not a locale code,
        // so it is preserved (the value is never silently altered).
        XCTAssertEqual(RatingBadgePolicy.displayRating("USA:PG"), "USA:PG")
        XCTAssertEqual(RatingBadgePolicy.displayRating("12:30"), "12:30")
    }
}
