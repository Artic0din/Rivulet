//
//  FocusMemoryTests.swift
//  RivuletTests
//
//  E2-PR3 — FocusMemory save/restore and stale-safe validated recall.
//

import XCTest
@testable import Rivulet

@MainActor
final class FocusMemoryTests: XCTestCase {

    private let memory = FocusMemory.shared

    override func setUp() {
        super.setUp()
        memory.clear()
    }

    override func tearDown() {
        memory.clear()
        super.tearDown()
    }

    func testRememberAndRecallRoundTrip() {
        memory.remember("row:2", for: "homeCW")
        XCTAssertEqual(memory.recall(for: "homeCW"), "row:2")
        XCTAssertTrue(memory.hasMemory(for: "homeCW"))
    }

    func testRecallNilWhenNothingRemembered() {
        XCTAssertNil(memory.recall(for: "unknownKey"))
        XCTAssertFalse(memory.hasMemory(for: "unknownKey"))
    }

    func testValidatedRecallReturnsRememberedWhenStillValid() {
        memory.remember("row:2", for: "homeCW")
        XCTAssertEqual(memory.recall(for: "homeCW", validIDs: ["row:1", "row:2"]), "row:2")
        // Memory is unchanged when valid.
        XCTAssertEqual(memory.recall(for: "homeCW"), "row:2")
    }

    func testValidatedRecallPrunesStaleAndReturnsNil() {
        memory.remember("row:2", for: "homeCW")
        // "row:2" no longer present after a refresh.
        XCTAssertNil(memory.recall(for: "homeCW", validIDs: ["row:1", "row:3"]))
        // Stale entry was pruned.
        XCTAssertNil(memory.recall(for: "homeCW"))
        XCTAssertFalse(memory.hasMemory(for: "homeCW"))
    }

    func testValidatedRecallNilWhenNoValidTargets() {
        memory.remember("row:2", for: "homeCW")
        XCTAssertNil(memory.recall(for: "homeCW", validIDs: []))
        XCTAssertFalse(memory.hasMemory(for: "homeCW"))
    }

    func testForgetRemovesSingleKeyOnly() {
        memory.remember("a", for: "k1")
        memory.remember("b", for: "k2")
        memory.forget(key: "k1")
        XCTAssertNil(memory.recall(for: "k1"))
        XCTAssertEqual(memory.recall(for: "k2"), "b")
    }
}
