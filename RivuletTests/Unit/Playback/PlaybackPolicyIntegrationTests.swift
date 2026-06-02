//
//  PlaybackPolicyIntegrationTests.swift
//  RivuletTests
//
//  E4-PR5B — proves the policy seams now wired into the live playback code
//  (UniversalPlayerViewModel player selection + routeSelected telemetry +
//  background pause; MediaDetailView resume/restart prompt) reproduce the
//  prior runtime behaviour exactly. These are the behaviour-preservation
//  contracts for the integration; the live call sites consult the same pure
//  policies under test here.
//

import XCTest
@testable import Rivulet

final class PlaybackPolicyIntegrationTests: XCTestCase {

    // MARK: - Player selection (UniversalPlayerViewModel.startPlayback)

    /// Historical rule: RPlayer unless `useApplePlayer` OR a forced video
    /// transcode. avKitFirst stays off → identical.
    func testPlayerSelectionMatchesLegacyRule() {
        func legacy(useApple: Bool, mustAV: Bool) -> Bool { !useApple && !mustAV } // true == RPlayer
        for useApple in [false, true] {
            for mustAV in [false, true] {
                let player = PlaybackRoutingPolicy.player(
                    RoutingInput(videoRequiresTranscode: mustAV, useApplePlayer: useApple, avKitFirst: false)
                )
                XCTAssertEqual(
                    player == .rivulet, legacy(useApple: useApple, mustAV: mustAV),
                    "useApple=\(useApple) mustAV=\(mustAV)"
                )
            }
        }
    }

    func testDefaultPlaybackStaysRPlayerFirst() {
        XCTAssertEqual(
            PlaybackRoutingPolicy.player(RoutingInput(useApplePlayer: false, avKitFirst: false)),
            .rivulet
        )
    }

    func testUseApplePlayerStillSelectsAVKit() {
        XCTAssertEqual(
            PlaybackRoutingPolicy.player(RoutingInput(useApplePlayer: true, avKitFirst: false)),
            .avKit
        )
    }

    func testForcedTranscodeStillSelectsAVKit() {
        XCTAssertEqual(
            PlaybackRoutingPolicy.player(RoutingInput(videoRequiresTranscode: true, useApplePlayer: false, avKitFirst: false)),
            .avKit
        )
    }

    func testAVKitFirstRemainsOffInIntegration() {
        // The integration always passes avKitFirst:false — no default flip.
        XCTAssertEqual(PlaybackRoutingPolicy.player(RoutingInput()).hashValue, PlaybackPlayer.rivulet.hashValue)
    }

    // MARK: - Resume prompt parity (MediaDetailView.presentPlay)

    private func makeItem(offsetSec: TimeInterval, runtimeSec: TimeInterval?) -> MediaItem {
        MediaItem(
            ref: MediaItemRef(providerID: "plex:test", itemID: "1"),
            kind: .movie,
            title: "T",
            sortTitle: nil,
            overview: nil,
            year: nil,
            runtime: runtimeSec,
            parentRef: nil,
            grandparentRef: nil,
            episodeNumber: nil,
            seasonNumber: nil,
            childProgress: nil,
            userState: MediaUserState(isPlayed: false, viewOffset: offsetSec, isFavorite: false, lastViewedAt: nil),
            artwork: MediaArtwork(poster: nil, backdrop: nil, thumbnail: nil, logo: nil),
            parentArtwork: nil,
            grandparentArtwork: nil
        )
    }

    /// The wiring's core invariant: `PlaybackResumePolicy.isInProgress` on the
    /// millisecond-converted offset/runtime equals `MediaItem.isInProgress` for
    /// representative values AND the 98% boundary. If this holds, the live
    /// `decide` call reproduces the old `item.isInProgress` gate exactly.
    func testIsInProgressEquivalenceWithMediaItem() {
        let cases: [(offset: TimeInterval, runtime: TimeInterval?)] = [
            (0, 100),          // not started
            (50, 100),         // mid
            (98, 100),         // exactly at 98% boundary → not in progress
            (97.9, 100),       // just under boundary → in progress
            (99, 100),         // near end → not in progress
            (10, 0),           // zero runtime
            (10, nil),         // unknown runtime (shows)
            (8880 * 0.5, 8880) // realistic movie offset
        ]
        for c in cases {
            let item = makeItem(offsetSec: c.offset, runtimeSec: c.runtime)
            let policyInProgress = PlaybackResumePolicy.isInProgress(
                viewOffsetMs: Int(c.offset * 1000),
                durationMs: Int((c.runtime ?? 0) * 1000)
            )
            XCTAssertEqual(policyInProgress, item.isInProgress, "offset=\(c.offset) runtime=\(String(describing: c.runtime))")
        }
    }

    /// The prompt fires only when the setting is on AND the item is in progress
    /// AND there is a real offset — mirroring the old `presentPlay` branch.
    func testPromptDecisionMatchesLegacyPresentPlay() {
        func legacyWouldPrompt(prompt: Bool, item: MediaItem) -> Bool {
            prompt && item.isInProgress && item.userState.viewOffset > 0
        }
        let items = [
            makeItem(offsetSec: 0, runtimeSec: 100),     // no offset
            makeItem(offsetSec: 50, runtimeSec: 100),    // in progress
            makeItem(offsetSec: 99, runtimeSec: 100),    // near end
            makeItem(offsetSec: 50, runtimeSec: nil)     // unknown runtime
        ]
        for prompt in [false, true] {
            for item in items {
                let decision = PlaybackResumePolicy.decide(
                    PlaybackResumePolicy.ResumeInput(
                        viewOffsetMs: Int(item.userState.viewOffset * 1000),
                        durationMs: Int((item.runtime ?? 0) * 1000),
                        promptEnabled: prompt,
                        explicitRestart: false,
                        isLive: false,
                        isTrailer: false
                    )
                )
                let didPrompt: Bool = { if case .prompt = decision { return true } else { return false } }()
                XCTAssertEqual(didPrompt, legacyWouldPrompt(prompt: prompt, item: item),
                               "prompt=\(prompt) offset=\(item.userState.viewOffset)")
            }
        }
    }

    func testPromptOffsetMatchesLegacyMilliseconds() {
        let item = makeItem(offsetSec: 50, runtimeSec: 100)
        let decision = PlaybackResumePolicy.decide(
            PlaybackResumePolicy.ResumeInput(
                viewOffsetMs: Int(item.userState.viewOffset * 1000),
                durationMs: Int((item.runtime ?? 0) * 1000),
                promptEnabled: true
            )
        )
        guard case .prompt(let offsetMs) = decision else { return XCTFail("expected prompt") }
        XCTAssertEqual(offsetMs, Int(item.userState.viewOffset * 1000)) // == legacy resumeChoiceTimeMs
    }

    // MARK: - Background pause parity (observeAppLifecycle)

    /// Legacy: pause only when `playbackState == .playing`. The policy returns
    /// `.pauseAwaitingUser` for `.playing` and `.noAction` otherwise.
    func testBackgroundPauseMatchesLegacyPlayingCheck() {
        let phases: [PlaybackPhase] = [.idle, .loading, .playing, .paused, .buffering, .ended, .failed]
        for phase in phases {
            let decision = PlaybackInterruptionRecoveryPolicy.decide(
                InterruptionInput(source: .appBackgrounded, player: .rivulet, phase: phase)
            )
            let wouldPause = (decision == .pauseAwaitingUser)
            XCTAssertEqual(wouldPause, phase == .playing, "phase=\(phase)")
        }
    }

    // MARK: - routeSelected telemetry safety

    /// The route name the integration emits is one of the anonymised cases
    /// (never a URL) for each primary route × player.
    func testRouteNameMappingIsAnonymised() {
        // RPlayer serves direct/remux via DirectPlay; AVKit keeps the family name.
        XCTAssertEqual(routeName(primary: "avPlayerDirect", rivulet: true), .rplayerDirectPlay)
        XCTAssertEqual(routeName(primary: "avPlayerDirect", rivulet: false), .avPlayerDirect)
        XCTAssertEqual(routeName(primary: "localRemux", rivulet: true), .rplayerDirectPlay)
        XCTAssertEqual(routeName(primary: "localRemux", rivulet: false), .localRemux)
        XCTAssertEqual(routeName(primary: "hls", rivulet: true), .hls)
        XCTAssertEqual(routeName(primary: "hls", rivulet: false), .hls)
    }

    /// Mirror of the integration's mapping (kept in sync with
    /// `UniversalPlayerViewModel.emitRouteSelectedTelemetry`).
    private func routeName(primary: String, rivulet: Bool) -> PlaybackTelemetry.RouteName {
        switch primary {
        case "avPlayerDirect": return rivulet ? .rplayerDirectPlay : .avPlayerDirect
        case "localRemux":     return rivulet ? .rplayerDirectPlay : .localRemux
        default:               return .hls
        }
    }

    func testRouteSelectedFieldsCarryNoSecret() {
        // Even a reasoning string that embedded a URL would be scrubbed at the sink.
        let event = PlaybackTelemetry.Event.routeSelected(
            PlaybackTelemetry.SafeContext(mediaType: "movie", ratingKey: "12345", codecFamily: "hevc", containerFamily: "mkv"),
            route: .rplayerDirectPlay,
            reason: "native_direct_play http://10.0.0.1:32400/x?X-Plex-Token=secret"
        )
        let fields = PlaybackTelemetry.fields(for: event)
        let joined = fields.values.joined(separator: " ")
        XCTAssertFalse(joined.contains("X-Plex-Token=secret"))
        XCTAssertFalse(joined.lowercased().contains("http"))
        XCTAssertFalse(joined.contains("://"))
        XCTAssertFalse(joined.contains("10.0.0.1"))
        XCTAssertEqual(fields["route"], "rplayerDirectPlay")
    }

    // MARK: - Fallback parity (E4-PR5C; UniversalPlayerViewModel AVPlayer path)

    /// The AVPlayer-path gate `shouldAttemptRivuletFallbackOnItemFailure` /
    /// `startWithFallback` now sources its decision from
    /// `PlaybackFallbackPolicy.decide(player: .avKit, …)`. The decision must be
    /// `.fallback` exactly when the old `planHasHLSFallback && !hasAttempted`
    /// gate was true (for the non-HLS primaries the AVPlayer path runs on).
    func testAVKitFallbackGateMatchesLegacyGate() {
        for family in [RouteFamily.avPlayerDirect, .localRemux] {
            for hlsAvailable in [false, true] {
                for attempted in [false, true] {
                    let decision = PlaybackFallbackPolicy.decide(
                        FallbackInput(
                            player: .avKit,
                            attemptedFamily: family,
                            failure: .unknown,
                            hlsFallbackAlreadyAttempted: attempted,
                            hlsRouteAvailable: hlsAvailable
                        )
                    )
                    let wouldFallback: Bool = { if case .fallback = decision { return true } else { return false } }()
                    let legacyGate = hlsAvailable && !attempted
                    XCTAssertEqual(wouldFallback, legacyGate,
                                   "family=\(family) hls=\(hlsAvailable) attempted=\(attempted)")
                }
            }
        }
    }

    /// On an HLS primary the AVPlayer path never auto-falls-back (legacy:
    /// `planHasHLSFallback` is false for HLS primaries → fallbacks empty).
    func testAVKitOnHLSNeverFallsBack() {
        let decision = PlaybackFallbackPolicy.decide(
            FallbackInput(player: .avKit, attemptedFamily: .hls, failure: .network, hlsRouteAvailable: false)
        )
        XCTAssertEqual(decision, .stopWithError)
    }

    /// The RPlayer path is terminal — `startRivuletPlayback` / `handlePipelineError`
    /// send `.failed` with no automatic route fallback.
    func testRPlayerNeverAutoFallsBack() {
        for family in [RouteFamily.avPlayerDirect, .localRemux, .hls] {
            XCTAssertEqual(
                PlaybackFallbackPolicy.decide(FallbackInput(player: .rivulet, attemptedFamily: family, failure: .decode)),
                .noFallback, "family=\(family)"
            )
        }
    }

    /// One-shot: a second AVKit fallback (already attempted) stops with error — no loop.
    func testAVKitFallbackIsOneShot() {
        let first = PlaybackFallbackPolicy.decide(
            FallbackInput(player: .avKit, attemptedFamily: .avPlayerDirect, failure: .decode)
        )
        XCTAssertEqual(first, .fallback(.hls))
        let second = PlaybackFallbackPolicy.decide(
            FallbackInput(player: .avKit, attemptedFamily: .hls, failure: .network, hlsFallbackAlreadyAttempted: true)
        )
        XCTAssertEqual(second, .stopWithError)
    }

    /// `routeFellBack` (emitted live in `attemptRivuletHLSFallback`) is secret-free.
    func testRouteFellBackFieldsCarryNoSecret() {
        let event = PlaybackTelemetry.Event.routeFellBack(
            PlaybackTelemetry.SafeContext(mediaType: "movie", ratingKey: "9", codecFamily: "h264", containerFamily: "mp4"),
            from: .avPlayerDirect,
            to: .hls,
            category: .decode
        )
        let fields = PlaybackTelemetry.fields(for: event)
        let joined = fields.values.joined(separator: " ")
        XCTAssertFalse(joined.lowercased().contains("http"))
        XCTAssertFalse(joined.contains("://"))
        XCTAssertEqual(fields["from"], "avPlayerDirect")
        XCTAssertEqual(fields["to"], "hls")
        XCTAssertEqual(fields["failure"], "decode")
    }
}
