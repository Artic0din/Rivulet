//
//  PreviewTransitionTests.swift
//  RivuletTests
//
//  E3-PR3 — lock the preview transition determinism contract and the
//  Reduce Motion gating policy.
//

import XCTest
import SwiftUI
@testable import Rivulet

final class PreviewStateMachineTests: XCTestCase {

    func testStartsInEntryMorphLocked() {
        let sm = PreviewStateMachine()
        XCTAssertEqual(sm.phase, .entryMorph)
        XCTAssertTrue(sm.motionLocked)
        XCTAssertTrue(sm.isCarouselInputEnabled)
        XCTAssertFalse(sm.isExpanded)
    }

    func testEntryMorphCompletesToCarousel() {
        var sm = PreviewStateMachine()
        sm.completeEntryMorph()
        XCTAssertEqual(sm.phase, .carouselStable)
        XCTAssertTrue(sm.isCarouselInputEnabled)
    }

    func testExpandFlowAndExpandedState() {
        var sm = PreviewStateMachine()
        sm.completeEntryMorph()
        sm.beginExpand()
        XCTAssertEqual(sm.phase, .expandingHero)
        XCTAssertTrue(sm.motionLocked)
        XCTAssertTrue(sm.isExpanded)              // expanding counts as expanded
        XCTAssertFalse(sm.isCarouselInputEnabled) // carousel input disabled mid-expand
        sm.finishExpand()
        XCTAssertEqual(sm.phase, .expandedHero)
        XCTAssertFalse(sm.motionLocked)
    }

    func testExitFromCarouselDismissesOverlay() {
        var sm = PreviewStateMachine()
        sm.completeEntryMorph()
        XCTAssertEqual(sm.exitAction(), .dismissOverlay)
    }

    func testExitFromExpandedCollapsesToCarousel() {
        var sm = PreviewStateMachine()
        sm.completeEntryMorph()
        sm.beginExpand()
        sm.finishExpand()
        let action = sm.exitAction()
        XCTAssertEqual(action, .collapseToCarousel)
        // exitAction collapses in place and unlocks motion.
        XCTAssertEqual(sm.phase, .carouselStable)
        XCTAssertFalse(sm.motionLocked)
    }

    func testExitFromDetailsStableCollapses() {
        var sm = PreviewStateMachine()
        sm.completeEntryMorph()
        sm.beginExpand()
        sm.finishExpand()
        sm.markDetailsStable()
        XCTAssertEqual(sm.phase, .detailsStable)
        XCTAssertEqual(sm.exitAction(), .collapseToCarousel)
    }

    func testGuardsRejectOutOfOrderTransitions() {
        var sm = PreviewStateMachine()
        // Cannot finishExpand before beginExpand.
        sm.finishExpand()
        XCTAssertEqual(sm.phase, .entryMorph)
        // Cannot beginExpand from a fresh entry without... actually entry is allowed.
        sm.completeEntryMorph()
        sm.finishExpand() // still no expand in progress
        XCTAssertEqual(sm.phase, .carouselStable)
    }

    func testCollapseToCarouselUnlocksMotion() {
        var sm = PreviewStateMachine()
        sm.completeEntryMorph()
        sm.beginExpand()
        sm.collapseToCarousel()
        XCTAssertEqual(sm.phase, .carouselStable)
        XCTAssertFalse(sm.motionLocked)
    }

    func testLoadGateGenerationInvalidatesStaleTokens() {
        var gate = PreviewLoadGate()
        let first = gate.begin()
        XCTAssertTrue(gate.isCurrent(first))
        let second = gate.begin()
        XCTAssertFalse(gate.isCurrent(first))
        XCTAssertTrue(gate.isCurrent(second))
    }
}

final class PreviewMotionPolicyTests: XCTestCase {

    func testReduceMotionSuppressesAnimation() {
        XCTAssertNil(PreviewMotionPolicy.animation(previewExpandAnimation, reduceMotion: true))
    }

    func testFullMotionReturnsBaseAnimation() {
        XCTAssertNotNil(PreviewMotionPolicy.animation(previewExpandAnimation, reduceMotion: false))
    }

    func testContinuousMotionGate() {
        XCTAssertFalse(PreviewMotionPolicy.allowsContinuousMotion(reduceMotion: true))
        XCTAssertTrue(PreviewMotionPolicy.allowsContinuousMotion(reduceMotion: false))
    }
}
