//
//  RenderStateResolverTests.swift
//  RivuletTests
//
//  Epic 2 (E2-PR1) — render-state precedence + transition coverage.
//  Verifies the single source of precedence truth that replaces the legacy
//  inline Home ladder: content > loading > error > empty.
//

import XCTest
@testable import Rivulet

final class RenderStateResolverTests: XCTestCase {

    // MARK: - Base resolution (loading → content / empty / error)

    func testLoadingWhenNoContentNoError() {
        let state: RenderState<[Int]> = RenderStateResolver.resolve(
            isLoading: true, content: nil, errorMessage: nil
        )
        XCTAssertEqual(state.phase, .loading)
        XCTAssertNil(state.content)
        XCTAssertNil(state.errorMessage)
    }

    func testContentWhenContentPresent() {
        let state: RenderState<[Int]> = RenderStateResolver.resolve(
            isLoading: false, content: [1, 2, 3], errorMessage: nil
        )
        XCTAssertEqual(state.phase, .content)
        XCTAssertEqual(state.content, [1, 2, 3])
    }

    func testEmptyWhenNotLoadingNoContentNoError() {
        let state: RenderState<[Int]> = RenderStateResolver.resolve(
            isLoading: false, content: nil, errorMessage: nil
        )
        XCTAssertEqual(state.phase, .empty)
    }

    func testErrorWhenNotLoadingNoContentWithError() {
        let state: RenderState<[Int]> = RenderStateResolver.resolve(
            isLoading: false, content: nil, errorMessage: "boom"
        )
        XCTAssertEqual(state.phase, .error)
        XCTAssertEqual(state.errorMessage, "boom")
    }

    // MARK: - Precedence

    func testContentWinsOverConcurrentLoading() {
        // A surface refreshing with existing content must keep showing content
        // (mirrors legacy "hubs non-empty always renders contentView").
        let state: RenderState<[Int]> = RenderStateResolver.resolve(
            isLoading: true, content: [1], errorMessage: "stale error"
        )
        XCTAssertEqual(state.phase, .content)
        XCTAssertEqual(state.content, [1])
    }

    func testLoadingWinsOverErrorWhenNoContent() {
        // Legacy ladder evaluates the loading branch before the error branch.
        let state: RenderState<[Int]> = RenderStateResolver.resolve(
            isLoading: true, content: nil, errorMessage: "boom"
        )
        XCTAssertEqual(state.phase, .loading)
    }

    func testErrorWinsOverEmptyWhenNoContent() {
        let state: RenderState<[Int]> = RenderStateResolver.resolve(
            isLoading: false, content: nil, errorMessage: "boom"
        )
        XCTAssertEqual(state.phase, .error)
    }

    // MARK: - Transition sequences (loading → X)

    func testTransitionLoadingToContent() {
        var state: RenderState<[Int]> = RenderStateResolver.resolve(isLoading: true, content: nil, errorMessage: nil)
        XCTAssertEqual(state.phase, .loading)
        state = RenderStateResolver.resolve(isLoading: false, content: [1], errorMessage: nil)
        XCTAssertEqual(state.phase, .content)
    }

    func testTransitionLoadingToEmpty() {
        var state: RenderState<[Int]> = RenderStateResolver.resolve(isLoading: true, content: nil, errorMessage: nil)
        XCTAssertEqual(state.phase, .loading)
        state = RenderStateResolver.resolve(isLoading: false, content: nil, errorMessage: nil)
        XCTAssertEqual(state.phase, .empty)
    }

    func testTransitionLoadingToError() {
        var state: RenderState<[Int]> = RenderStateResolver.resolve(isLoading: true, content: nil, errorMessage: nil)
        XCTAssertEqual(state.phase, .loading)
        state = RenderStateResolver.resolve(isLoading: false, content: nil, errorMessage: "net down")
        XCTAssertEqual(state.phase, .error)
        XCTAssertEqual(state.errorMessage, "net down")
    }

    // MARK: - Phase / payload accessors

    func testPhaseEnumIsExhaustiveAndStable() {
        XCTAssertEqual(Set(RenderStatePhase.allCases), [.loading, .content, .empty, .error])
        XCTAssertEqual(RenderStatePhase.loading.rawValue, "loading")
    }

    func testEquatableWhenContentEquatable() {
        let a: RenderState<[Int]> = .content([1, 2])
        let b: RenderState<[Int]> = .content([1, 2])
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, .content([3]))
        XCTAssertNotEqual(RenderState<[Int]>.loading, .empty)
    }
}
