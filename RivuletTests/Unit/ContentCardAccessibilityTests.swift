//
//  ContentCardAccessibilityTests.swift
//  RivuletTests
//
//  E3-PR7 — combined VoiceOver label for content cards.
//

import XCTest
@testable import Rivulet

final class ContentCardAccessibilityTests: XCTestCase {

    func testFullLabelOrdersTitleInfoBadges() {
        let label = ContentCardAccessibility.label(
            title: "Dune: Part Two",
            infoLine: ["M", "2024", "2h 46m"],
            badges: ["4K", "Dolby Vision", "Atmos"]
        )
        XCTAssertEqual(label, "Dune: Part Two, M, 2024, 2h 46m, 4K, Dolby Vision, Atmos")
    }

    func testTitleOnly() {
        XCTAssertEqual(ContentCardAccessibility.label(title: "Severance", infoLine: [], badges: []), "Severance")
    }

    func testTitleAndInfoNoBadges() {
        XCTAssertEqual(
            ContentCardAccessibility.label(title: "Show", infoLine: ["TV-MA", "2022"], badges: []),
            "Show, TV-MA, 2022"
        )
    }

    func testTitleFirstAlways() {
        let label = ContentCardAccessibility.label(title: "First", infoLine: ["x"], badges: ["y"])
        XCTAssertTrue(label.hasPrefix("First"))
    }
}
