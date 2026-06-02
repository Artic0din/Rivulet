//
//  PlaybackInterruptionRecoveryPolicyTests.swift
//  RivuletTests
//
//  E4-PR5 — interruption / recovery policy. Locks the policy as a faithful mirror
//  of current behaviour: background pause / foreground hold, diagnostics-only
//  audio interruptions, in-place audio recovery, remux buffer auto-resume, dead
//  read-loop rebuild, the AirPlay-instability ladder (recover → stereo rebuild →
//  abandon), one-shot fatal fallback delegation, and telemetry-safe mapping.
//

import XCTest
@testable import Rivulet

final class PlaybackInterruptionRecoveryPolicyTests: XCTestCase {

    private typealias Policy = PlaybackInterruptionRecoveryPolicy

    private func input(
        _ source: InterruptionSource,
        player: PlaybackPlayer = .rivulet,
        phase: PlaybackPhase = .playing,
        pausedDueToBackground: Bool = false,
        isRemux: Bool = false,
        attemptedFamily: RouteFamily = .avPlayerDirect,
        hlsFallbackAlreadyAttempted: Bool = false,
        hlsRouteAvailable: Bool = true
    ) -> InterruptionInput {
        InterruptionInput(
            source: source,
            player: player,
            phase: phase,
            pausedDueToBackground: pausedDueToBackground,
            isRemux: isRemux,
            attemptedFamily: attemptedFamily,
            hlsFallbackAlreadyAttempted: hlsFallbackAlreadyAttempted,
            hlsRouteAvailable: hlsRouteAvailable
        )
    }

    // MARK: - App backgrounding / foregrounding

    func testBackgroundWhilePlayingPausesAwaitingUser() {
        XCTAssertEqual(Policy.decide(input(.appBackgrounded, phase: .playing)), .pauseAwaitingUser)
    }

    func testBackgroundWhilePausedDoesNothing() {
        XCTAssertEqual(Policy.decide(input(.appBackgrounded, phase: .paused)), .noAction)
    }

    func testForegroundAfterBackgroundPauseStaysPaused() {
        // Returning from a background-induced pause keeps it paused (manual resume).
        XCTAssertEqual(
            Policy.decide(input(.appForegrounded, phase: .paused, pausedDueToBackground: true)),
            .pauseAwaitingUser
        )
    }

    func testForegroundWithoutBackgroundPauseDoesNothing() {
        XCTAssertEqual(
            Policy.decide(input(.appForegrounded, phase: .playing, pausedDueToBackground: false)),
            .noAction
        )
    }

    // MARK: - Audio session interruption (diagnostics-only on tvOS)

    func testAudioInterruptionBeganIsLogOnly() {
        XCTAssertEqual(Policy.decide(input(.audioSessionInterruptionBegan)), .logOnly)
    }

    func testAudioInterruptionEndedIsLogOnlyRegardlessOfShouldResume() {
        XCTAssertEqual(Policy.decide(input(.audioSessionInterruptionEnded(shouldResume: true))), .logOnly)
        XCTAssertEqual(Policy.decide(input(.audioSessionInterruptionEnded(shouldResume: false))), .logOnly)
    }

    // MARK: - Route / renderer recovery (in place)

    func testRouteChangeRecoversAudioInPlace() {
        XCTAssertEqual(Policy.decide(input(.audioRouteChanged)), .recoverAudio)
    }

    func testAutoFlushRecoversAudioInPlace() {
        XCTAssertEqual(Policy.decide(input(.audioRendererAutoFlush)), .recoverAudio)
    }

    func testOutputConfigChangeRecoversOnlyWhilePlaying() {
        XCTAssertEqual(Policy.decide(input(.audioOutputConfigurationChanged, phase: .playing)), .recoverAudio)
        XCTAssertEqual(Policy.decide(input(.audioOutputConfigurationChanged, phase: .paused)), .noAction)
    }

    // MARK: - Rebuffer / stall

    func testBufferUnderrunShowsBuffering() {
        XCTAssertEqual(Policy.decide(input(.bufferUnderrun, phase: .playing)), .showBuffering)
    }

    func testRemuxBufferRecoveredResumesFromPausedOrBuffering() {
        XCTAssertEqual(Policy.decide(input(.bufferRecovered, phase: .paused, isRemux: true)), .resumeImmediately)
        XCTAssertEqual(Policy.decide(input(.bufferRecovered, phase: .buffering, isRemux: true)), .resumeImmediately)
    }

    func testBufferRecoveredDoesNotResumeNonRemux() {
        // RPlayer refills its own buffers; no AVPlayer-style keepUp auto-resume.
        XCTAssertEqual(Policy.decide(input(.bufferRecovered, phase: .paused, isRemux: false)), .noAction)
    }

    func testBufferRecoveredWhilePlayingDoesNothing() {
        XCTAssertEqual(Policy.decide(input(.bufferRecovered, phase: .playing, isRemux: true)), .noAction)
    }

    // MARK: - Dead read-loop rebuild / user retry

    func testReadLoopDiedRebuildsPlayer() {
        XCTAssertEqual(Policy.decide(input(.readLoopDied, phase: .paused)), .rebuildPlayer)
    }

    func testUserRetryRestarts() {
        XCTAssertEqual(Policy.decide(input(.userRetry, phase: .failed)), .retryPlayback)
    }

    // MARK: - Fatal fallback (delegated to PlaybackFallbackPolicy)
    //
    // E4-PR5C corrected the live model: the AVPlayer (AVKit) path falls back to
    // HLS once; the RPlayer (rivulet) path is terminal (no auto fallback).

    func testAVKitDirectFatalFallsBackToHLSOnce() {
        let decision = Policy.decide(input(
            .fatalError(.decode),
            player: .avKit,
            phase: .failed,
            attemptedFamily: .avPlayerDirect,
            hlsFallbackAlreadyAttempted: false
        ))
        XCTAssertEqual(decision, .fallbackRoute(.hls))
    }

    func testAVKitFatalAfterFallbackSpentShowsError() {
        let decision = Policy.decide(input(
            .fatalError(.decode),
            player: .avKit,
            phase: .failed,
            attemptedFamily: .hls,
            hlsFallbackAlreadyAttempted: true
        ))
        XCTAssertEqual(decision, .showPlaybackError)
    }

    func testAVKitFatalWithNoHLSRouteShowsError() {
        let decision = Policy.decide(input(
            .fatalError(.network),
            player: .avKit,
            phase: .failed,
            attemptedFamily: .avPlayerDirect,
            hlsRouteAvailable: false
        ))
        XCTAssertEqual(decision, .showPlaybackError)
    }

    func testRPlayerFatalIsTerminalNoAutoFallback() {
        // RPlayer failures surface a calm error and rely on user retry — never
        // an automatic route fallback, regardless of HLS availability.
        for family in [RouteFamily.avPlayerDirect, .localRemux, .hls] {
            let decision = Policy.decide(input(
                .fatalError(.decode),
                player: .rivulet,
                phase: .failed,
                attemptedFamily: family
            ))
            XCTAssertEqual(decision, .showPlaybackError, "family=\(family)")
        }
    }

    func testAVKitFatalAlreadyOnHLSShowsError() {
        let decision = Policy.decide(input(
            .fatalError(.network),
            player: .avKit,
            phase: .failed,
            attemptedFamily: .hls
        ))
        XCTAssertEqual(decision, .showPlaybackError)
    }

    // MARK: - AirPlay instability ladder

    func testAirPlayBelowThresholdRecoversInPlace() {
        let decision = Policy.airPlayInstabilityDecision(.init(autoFlushCount: 1))
        XCTAssertEqual(decision, .recoverAudio)
    }

    func testAirPlayCrossingLowerThresholdRebuildsInStereo() {
        // rendererFailure >= 1 crosses the stereo-fallback threshold.
        let decision = Policy.airPlayInstabilityDecision(.init(rendererFailureCount: 1))
        XCTAssertEqual(decision, .rebuildPlayer)
    }

    func testAirPlayTwoAutoFlushesRebuildsInStereo() {
        XCTAssertEqual(
            Policy.airPlayInstabilityDecision(.init(autoFlushCount: 2)),
            .rebuildPlayer
        )
    }

    func testAirPlayStereoNotRetriedOnceFellBack() {
        // Already fell back → cannot rebuild again; below hard-unstable → recover.
        let decision = Policy.airPlayInstabilityDecision(.init(
            autoFlushCount: 2,
            alreadyFellBackToStereo: true
        ))
        XCTAssertEqual(decision, .recoverAudio)
    }

    func testAirPlayHardUnstableAbandonsAfterFallbackSpent() {
        // Fallback spent + hard-unstable counts → abandon (report failure).
        let decision = Policy.airPlayInstabilityDecision(.init(
            autoFlushCount: 3,
            alreadyFellBackToStereo: true
        ))
        XCTAssertEqual(decision, .abandonRecovery)
    }

    func testAirPlayNoStereoDifferenceCannotRebuild() {
        // When the stereo policy equals the default, a fallback would not change
        // behaviour, so below hard-unstable it just recovers in place.
        let decision = Policy.airPlayInstabilityDecision(.init(
            autoFlushCount: 2,
            stereoPolicyDiffers: false
        ))
        XCTAssertEqual(decision, .recoverAudio)
    }

    func testAirPlayInFlightDoesNotStartAnotherRebuild() {
        let decision = Policy.airPlayInstabilityDecision(.init(
            rendererFailureCount: 1,
            fallbackInFlight: true
        ))
        XCTAssertEqual(decision, .recoverAudio)
    }

    func testAirPlayRendererFailureTwiceIsHardUnstable() {
        // 2 renderer failures with no stereo option left → abandon.
        let decision = Policy.airPlayInstabilityDecision(.init(
            rendererFailureCount: 2,
            stereoPolicyDiffers: false
        ))
        XCTAssertEqual(decision, .abandonRecovery)
    }

    func testAirPlayLadderTerminatesNoInfiniteLoop() {
        // Escalating counts after the stereo fallback is spent must converge to
        // abandonRecovery — never oscillate back to rebuild.
        var spent = Policy.AirPlayInstabilityInput(alreadyFellBackToStereo: true)
        for n in 1...6 {
            spent.autoFlushCount = n
            let decision = Policy.airPlayInstabilityDecision(spent)
            XCTAssertNotEqual(decision, .rebuildPlayer, "must not rebuild again once stereo fallback is spent")
            if n >= 3 { XCTAssertEqual(decision, .abandonRecovery) }
        }
    }

    // MARK: - Telemetry mapping (E4-PR2 contract; safe by construction)

    func testTelemetryStallForBuffering() {
        let event = Policy.telemetryEvent(for: .showBuffering, context: .init())
        guard case .stall = event else { return XCTFail("expected stall") }
    }

    func testTelemetryRecoveredForResume() {
        let event = Policy.telemetryEvent(for: .resumeImmediately, context: .init())
        guard case .recovered(_, let result) = event else { return XCTFail("expected recovered") }
        XCTAssertEqual(result, .recovered)
    }

    func testTelemetryFellBackForRebuildAndFallback() {
        for decision in [RecoveryDecision.rebuildPlayer, .fallbackRoute(.hls)] {
            let event = Policy.telemetryEvent(for: decision, context: .init())
            guard case .recovered(_, let result) = event else { return XCTFail("expected recovered") }
            XCTAssertEqual(result, .fellBack)
        }
    }

    func testTelemetryFailedForAbandonAndError() {
        for decision in [RecoveryDecision.abandonRecovery, .showPlaybackError] {
            let event = Policy.telemetryEvent(for: decision, context: .init())
            guard case .recovered(_, let result) = event else { return XCTFail("expected recovered") }
            XCTAssertEqual(result, .failed)
        }
    }

    func testTelemetryNilForRoutineDecisions() {
        for decision in [RecoveryDecision.noAction, .logOnly, .pauseAwaitingUser, .recoverAudio, .retryPlayback] {
            XCTAssertNil(Policy.telemetryEvent(for: decision, context: .init()))
        }
    }

    // MARK: - Telemetry safety: no secret can be expressed

    func testTelemetryFieldsCarryNoURLOrToken() {
        // Even if a SafeContext field were abused with a URL, the contract scrubs it.
        let ctx = PlaybackTelemetry.SafeContext(ratingKey: "http://10.0.0.1:32400/x?X-Plex-Token=abc")
        guard let event = Policy.telemetryEvent(for: .showBuffering, context: ctx) else {
            return XCTFail("expected event")
        }
        let fields = PlaybackTelemetry.fields(for: event)
        let joined = fields.values.joined(separator: " ")
        XCTAssertFalse(joined.contains("X-Plex-Token=abc"))
        XCTAssertFalse(joined.lowercased().contains("http"))
        XCTAssertFalse(joined.contains("://"))
        XCTAssertFalse(joined.contains("10.0.0.1"))
    }
}
