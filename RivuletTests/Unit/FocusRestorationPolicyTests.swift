//
//  FocusRestorationPolicyTests.swift
//  RivuletTests
//
//  E2-PR3 — pure focus-identity and restoration rules. Proves focus is restored
//  across refresh only to still-valid items and never stranded on a vanished id.
//

import XCTest
@testable import Rivulet

final class FocusRestorationPolicyTests: XCTestCase {

    // MARK: - FocusID

    func testFocusIDBuildsCanonicalString() {
        XCTAssertEqual(FocusID.make(rowID: "home:cw", itemID: "123"), "home:cw:123")
        XCTAssertEqual(FocusID.make(rowID: "row", itemID: "abc"), "row:abc")
    }

    // MARK: - restoredFocusID

    func testRestoresWhenSavedStillValid() {
        let valid: Set<String> = ["row:1", "row:2", "row:3"]
        XCTAssertEqual(FocusRestorationPolicy.restoredFocusID(saved: "row:2", validFocusIDs: valid), "row:2")
    }

    func testDropsRestoreWhenSavedNoLongerValid() {
        let valid: Set<String> = ["row:1", "row:3"]
        XCTAssertNil(FocusRestorationPolicy.restoredFocusID(saved: "row:2", validFocusIDs: valid))
    }

    func testDropsRestoreWhenSavedNil() {
        XCTAssertNil(FocusRestorationPolicy.restoredFocusID(saved: nil, validFocusIDs: ["row:1"]))
    }

    func testDropsRestoreWhenNoValidTargets() {
        XCTAssertNil(FocusRestorationPolicy.restoredFocusID(saved: "row:1", validFocusIDs: []))
    }

    func testRestorationHandlesColonContainingRowIDs() {
        // rowID "home:recommendations" + itemID "42" → must match as a whole.
        let id = FocusID.make(rowID: "home:recommendations", itemID: "42")
        XCTAssertEqual(id, "home:recommendations:42")
        XCTAssertEqual(
            FocusRestorationPolicy.restoredFocusID(saved: id, validFocusIDs: [id, "home:recommendations:43"]),
            id
        )
        XCTAssertNil(
            FocusRestorationPolicy.restoredFocusID(saved: id, validFocusIDs: ["home:recommendations:43"])
        )
    }

    // MARK: - entryFocusID

    func testEntryPrefersValidRemembered() {
        XCTAssertEqual(
            FocusRestorationPolicy.entryFocusID(remembered: "row:2", orderedValidFocusIDs: ["row:1", "row:2"]),
            "row:2"
        )
    }

    func testEntryFallsBackToFirstWhenRememberedStale() {
        XCTAssertEqual(
            FocusRestorationPolicy.entryFocusID(remembered: "row:9", orderedValidFocusIDs: ["row:1", "row:2"]),
            "row:1"
        )
    }

    func testEntryFallsBackToFirstWhenNoMemory() {
        XCTAssertEqual(
            FocusRestorationPolicy.entryFocusID(remembered: nil, orderedValidFocusIDs: ["row:5", "row:6"]),
            "row:5"
        )
    }

    func testEntryNilWhenNothingFocusable() {
        XCTAssertNil(FocusRestorationPolicy.entryFocusID(remembered: "row:1", orderedValidFocusIDs: []))
        XCTAssertNil(FocusRestorationPolicy.entryFocusID(remembered: nil, orderedValidFocusIDs: []))
    }
}
