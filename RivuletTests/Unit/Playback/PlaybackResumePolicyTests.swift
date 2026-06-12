//
//  PlaybackResumePolicyTests.swift
//  RivuletTests
//
//  E4-PR4 — resume / start-offset policy. Locks the policy as a faithful mirror
//  of current behaviour (prompt vs auto-resume, near-end, live/trailer, restart)
//  and proves a single seek source.
//

import XCTest
@testable import Rivulet

final class PlaybackResumePolicyTests: XCTestCase {

    private typealias Policy = PlaybackResumePolicy
    private typealias Input = PlaybackResumePolicy.ResumeInput

    private let duration = 60 * 60 * 1000 // 1h in ms

    // MARK: - Beginning vs resume

    func testNilLikeZeroOffsetStartsAtBeginning() {
        XCTAssertEqual(Policy.decide(Input(viewOffsetMs: 0, durationMs: duration)), .startAtBeginning)
    }

    func testValidOffsetResumesWhenPromptDisabled() {
        let d = Policy.decide(Input(viewOffsetMs: 10 * 60 * 1000, durationMs: duration, promptEnabled: false))
        XCTAssertEqual(d, .resume(offsetMs: 10 * 60 * 1000))
    }

    func testExplicitRestartStartsAtBeginning() {
        let d = Policy.decide(Input(viewOffsetMs: 10 * 60 * 1000, durationMs: duration,
                                    promptEnabled: true, explicitRestart: true))
        XCTAssertEqual(d, .startAtBeginning)
    }

    // MARK: - Prompt

    func testPromptWhenEnabledAndInProgress() {
        let d = Policy.decide(Input(viewOffsetMs: 10 * 60 * 1000, durationMs: duration, promptEnabled: true))
        XCTAssertEqual(d, .prompt(offsetMs: 10 * 60 * 1000))
    }

    func testNoPromptWhenSettingDisabled() {
        let d = Policy.decide(Input(viewOffsetMs: 10 * 60 * 1000, durationMs: duration, promptEnabled: false))
        XCTAssertEqual(d, .resume(offsetMs: 10 * 60 * 1000))
    }

    func testPromptChoiceResolves() {
        XCTAssertEqual(Policy.resolvePromptChoice(offsetMs: 5000, userChoseRestart: true), .startAtBeginning)
        XCTAssertEqual(Policy.resolvePromptChoice(offsetMs: 5000, userChoseRestart: false), .resume(offsetMs: 5000))
    }

    // MARK: - Near-end / over-duration (existing behaviour)

    func testNearEndIsNotInProgressSoNoPrompt() {
        // 99% watched → not in progress → no prompt even when enabled; mirrors
        // existing behaviour (resumes at the stored offset, player clamps).
        let offset = Int(Double(duration) * 0.99)
        let d = Policy.decide(Input(viewOffsetMs: offset, durationMs: duration, promptEnabled: true))
        XCTAssertEqual(d, .resume(offsetMs: offset))
    }

    func testInProgressThresholdBoundary() {
        XCTAssertTrue(Policy.isInProgress(viewOffsetMs: Int(Double(duration) * 0.97), durationMs: duration))
        XCTAssertFalse(Policy.isInProgress(viewOffsetMs: Int(Double(duration) * 0.98), durationMs: duration))
        XCTAssertFalse(Policy.isInProgress(viewOffsetMs: 0, durationMs: duration))
        XCTAssertFalse(Policy.isInProgress(viewOffsetMs: 1000, durationMs: 0))
    }

    func testOffsetLargerThanDurationResumesRaw() {
        // No resolution-time clamp today (the player engine clamps); not in
        // progress so no prompt. Mirrors existing behaviour.
        let offset = duration + 5000
        let d = Policy.decide(Input(viewOffsetMs: offset, durationMs: duration, promptEnabled: true))
        XCTAssertEqual(d, .resume(offsetMs: offset))
    }

    // MARK: - Live / trailer ignore resume

    func testLiveTVIgnoresResume() {
        let d = Policy.decide(Input(viewOffsetMs: 10 * 60 * 1000, durationMs: duration, promptEnabled: true, isLive: true))
        XCTAssertEqual(d, .startAtBeginning)
    }

    func testTrailerIgnoresResume() {
        let d = Policy.decide(Input(viewOffsetMs: 30 * 1000, durationMs: duration, isTrailer: true))
        XCTAssertEqual(d, .startAtBeginning)
    }

    // MARK: - Single seek source (no duplicate seek)

    func testSeekOffsetSingleSource() {
        XCTAssertEqual(Policy.seekOffsetMs(for: .resume(offsetMs: 7777)), 7777)
        XCTAssertNil(Policy.seekOffsetMs(for: .startAtBeginning))
        XCTAssertNil(Policy.seekOffsetMs(for: .prompt(offsetMs: 7777))) // seek after choice
    }

    func testDecisionIsDeterministic() {
        let input = Input(viewOffsetMs: 12345, durationMs: duration, promptEnabled: true)
        XCTAssertEqual(Policy.decide(input), Policy.decide(input))
    }

    // MARK: - Launch-closure offset computation mirror

    func testStartOffsetComputationMirror() {
        XCTAssertNil(Policy.startOffsetMs(playFromBeginning: true, viewOffsetMs: 9999))
        XCTAssertEqual(Policy.startOffsetMs(playFromBeginning: false, viewOffsetMs: 9999), 9999)
        XCTAssertNil(Policy.startOffsetMs(playFromBeginning: false, viewOffsetMs: 0))
    }
}
