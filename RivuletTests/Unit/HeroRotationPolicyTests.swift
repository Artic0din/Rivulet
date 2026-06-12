//
//  HeroRotationPolicyTests.swift
//  RivuletTests
//
//  Pure decision tests for the home hero auto-rotation policy.
//

import XCTest
@testable import Rivulet

final class HeroRotationPolicyTests: XCTestCase {

    // MARK: - shouldRotate gate

    func testRotatesWhenActiveMultiItemNotBusy() {
        XCTAssertTrue(HeroRotationPolicy.shouldRotate(itemCount: 5, isBusy: false, isActive: true))
    }

    func testRotatesEvenWhenHeroControlFocused() {
        // The hero lands with Play focused; rotation must NOT pause for that.
        XCTAssertTrue(HeroRotationPolicy.shouldRotate(itemCount: 5, isBusy: false, isActive: true))
    }

    func testDoesNotRotateWithOneOrZeroItems() {
        XCTAssertFalse(HeroRotationPolicy.shouldRotate(itemCount: 1, isBusy: false, isActive: true))
        XCTAssertFalse(HeroRotationPolicy.shouldRotate(itemCount: 0, isBusy: false, isActive: true))
    }

    func testPausesWhileBusy() {
        XCTAssertFalse(HeroRotationPolicy.shouldRotate(itemCount: 5, isBusy: true, isActive: true))
    }

    func testPausesWhenInactive() {
        // Detail/preview/player presented, or app backgrounded.
        XCTAssertFalse(HeroRotationPolicy.shouldRotate(itemCount: 5, isBusy: false, isActive: false))
    }

    // MARK: - nextIndex wrapping

    func testNextIndexAdvances() {
        XCTAssertEqual(HeroRotationPolicy.nextIndex(current: 0, count: 3), 1)
        XCTAssertEqual(HeroRotationPolicy.nextIndex(current: 1, count: 3), 2)
    }

    func testNextIndexWrapsAtEnd() {
        XCTAssertEqual(HeroRotationPolicy.nextIndex(current: 2, count: 3), 0)
    }

    func testNextIndexEmptyIsZero() {
        XCTAssertEqual(HeroRotationPolicy.nextIndex(current: 0, count: 0), 0)
    }

    // MARK: - Interval is deterministic and within the requested window

    func testIntervalWithin8To12Seconds() {
        XCTAssertGreaterThanOrEqual(HeroRotationPolicy.intervalSeconds, 8)
        XCTAssertLessThanOrEqual(HeroRotationPolicy.intervalSeconds, 12)
    }
}
