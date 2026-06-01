//
//  DiscoverPresentationTests.swift
//  RivuletTests
//
//  E3-PR5 — deterministic Discover render-state resolution.
//

import XCTest
@testable import Rivulet

final class DiscoverPresentationTests: XCTestCase {

    func testContentWinsOverLoading() {
        XCTAssertEqual(DiscoverPresentation.phase(isLoading: true, hasContent: true), .content)
    }

    func testLoadingWhenNoContent() {
        XCTAssertEqual(DiscoverPresentation.phase(isLoading: true, hasContent: false), .loading)
    }

    func testEmptyWhenIdleAndNoContent() {
        XCTAssertEqual(DiscoverPresentation.phase(isLoading: false, hasContent: false), .empty)
    }

    func testContentWhenIdleWithContent() {
        XCTAssertEqual(DiscoverPresentation.phase(isLoading: false, hasContent: true), .content)
    }
}
