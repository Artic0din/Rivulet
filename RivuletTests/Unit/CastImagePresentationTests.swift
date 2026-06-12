//
//  CastImagePresentationTests.swift
//  RivuletTests
//
//  E3-PR11 — cast/crew label + initials fallback.
//

import XCTest
@testable import Rivulet

final class CastImagePresentationTests: XCTestCase {

    func testLabelWithRole() {
        XCTAssertEqual(CastImagePresentation.accessibilityLabel(name: "Scott Grimes", role: "Dr. Archie Morris"), "Scott Grimes, Dr. Archie Morris")
    }

    func testLabelWithoutRole() {
        XCTAssertEqual(CastImagePresentation.accessibilityLabel(name: "John Wells", role: nil), "John Wells")
        XCTAssertEqual(CastImagePresentation.accessibilityLabel(name: "John Wells", role: "  "), "John Wells")
    }

    func testInitialsTwoNames() {
        XCTAssertEqual(CastImagePresentation.initials(from: "Parminder Nagra"), "PN")
    }

    func testInitialsSingleName() {
        XCTAssertEqual(CastImagePresentation.initials(from: "Cher"), "C")
    }

    func testInitialsThreeNamesCapsAtTwo() {
        XCTAssertEqual(CastImagePresentation.initials(from: "Mary Jane Watson"), "MJ")
    }

    func testInitialsEmpty() {
        XCTAssertEqual(CastImagePresentation.initials(from: ""), "?")
        XCTAssertEqual(CastImagePresentation.initials(from: "   "), "?")
    }
}
