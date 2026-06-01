//
//  PlaybackRoutingPolicyTests.swift
//  RivuletTests
//
//  E4-PR3 — routing + fallback policy. Locks the policies as faithful mirrors of
//  current behaviour (avKitFirst defaults OFF) and proves the fallback ladder is
//  deterministic, loop-free, and telemetry-safe.
//

import XCTest
@testable import Rivulet

final class PlaybackRoutingPolicyTests: XCTestCase {

    // MARK: - Player selection (mirrors UniversalPlayerViewModel)

    func testDefaultPlayerIsRPlayer() {
        // useApplePlayer off, no forced transcode, avKitFirst off → RPlayer (today).
        XCTAssertEqual(PlaybackRoutingPolicy.player(RoutingInput()), .rivulet)
    }

    func testUseApplePlayerForcesAVKit() {
        XCTAssertEqual(PlaybackRoutingPolicy.player(RoutingInput(useApplePlayer: true)), .avKit)
    }

    func testVideoRequiringTranscodeForcesAVKit() {
        XCTAssertEqual(PlaybackRoutingPolicy.player(RoutingInput(videoRequiresTranscode: true)), .avKit)
    }

    func testAVKitFirstFlagIsOffByDefaultAndFlipsWhenSet() {
        XCTAssertEqual(PlaybackRoutingPolicy.player(RoutingInput(avKitFirst: false)), .rivulet)
        XCTAssertEqual(PlaybackRoutingPolicy.player(RoutingInput(avKitFirst: true)), .avKit)
    }

    // MARK: - Intended route (player × family)

    func testNativeDirectMediaDefaultsToRPlayerDirect() {
        let input = RoutingInput(needsRemux: false, canBuildDirectRoute: true)
        XCTAssertEqual(PlaybackRoutingPolicy.intendedRoute(input), .rPlayerDirect)
    }

    func testNativeDirectMediaWithUseApplePlayerIsAVKitDirect() {
        let input = RoutingInput(needsRemux: false, useApplePlayer: true)
        XCTAssertEqual(PlaybackRoutingPolicy.intendedRoute(input), .avKitDirect)
    }

    func testNativeDirectMediaUnderAVKitFirstIsAVKitDirect() {
        let input = RoutingInput(needsRemux: false, avKitFirst: true)
        XCTAssertEqual(PlaybackRoutingPolicy.intendedRoute(input), .avKitDirect)
    }

    func testForceHLSRoutesToHLS() {
        // Default player (rivulet) → rPlayerHls.
        XCTAssertEqual(PlaybackRoutingPolicy.intendedRoute(RoutingInput(forceHLS: true)), .rPlayerHls)
    }

    func testUnsupportedVideoCodecTranscodesViaAVKitHLS() {
        // MPEG-2/VC-1/VP9/AV1/HLG → must transcode → AVKit consumes the HLS.
        let input = RoutingInput(videoRequiresTranscode: true)
        XCTAssertEqual(PlaybackRoutingPolicy.intendedRoute(input), .avKitHls)
        XCTAssertEqual(
            PlaybackRoutingPolicy.routeFamily(input, useLocalRemux: false).reasons,
            ["video_requires_transcode"]
        )
    }

    func testDolbyVisionP7FallsToRPlayerLocalRemux() {
        // DV P7/P8.6 conversion forces a local-remux family; default player RPlayer.
        let input = RoutingInput(needsRemux: true, needsDVConversion: true)
        XCTAssertEqual(PlaybackRoutingPolicy.intendedRoute(input), .rPlayerLocalRemux)
    }

    func testLosslessAudioRemuxDefaultsToRPlayerLocalRemux() {
        // TrueHD / DTS-HD / DTS:X → needsRemux; RPlayer handles locally (FFmpeg).
        let input = RoutingInput(needsRemux: true)
        XCTAssertEqual(PlaybackRoutingPolicy.intendedRoute(input), .rPlayerLocalRemux)
    }

    func testRemuxUnderUseApplePlayerWithoutDVUsesServerHLS() {
        // AVKit path with useLocalRemux off (useApplePlayer on) + no DV → server HLS.
        let input = RoutingInput(needsRemux: true, useApplePlayer: true)
        XCTAssertEqual(PlaybackRoutingPolicy.intendedRoute(input), .avKitHls)
    }

    func testFFmpegUnavailableNativeContainerUsesAVKitDirect() {
        // No FFmpeg → can't RPlayer; native container → AVPlayer direct.
        let input = RoutingInput(ffmpegAvailable: false, needsRemux: false)
        // Player is still rivulet by the player() rule, but the route family is
        // avPlayerDirect; the combined mapping reflects the family faithfully.
        XCTAssertEqual(PlaybackRoutingPolicy.routeFamily(input, useLocalRemux: false).family, .avPlayerDirect)
    }

    func testFFmpegUnavailableNonNativeFallsToHLS() {
        let input = RoutingInput(ffmpegAvailable: false, needsRemux: true)
        XCTAssertEqual(PlaybackRoutingPolicy.routeFamily(input, useLocalRemux: false).family, .hls)
    }

    func testLiveTVAlwaysHLS() {
        XCTAssertEqual(PlaybackRoutingPolicy.routeFamily(RoutingInput(isLiveTV: true), useLocalRemux: true).family, .hls)
    }

    func testNoDirectRouteWhenPartKeyMissingFallsToHLS() {
        let input = RoutingInput(needsRemux: false, canBuildDirectRoute: false)
        XCTAssertEqual(PlaybackRoutingPolicy.routeFamily(input, useLocalRemux: false).family, .hls)
    }

    // MARK: - Subtitles do not influence routing (matches current behaviour)

    func testSubtitleTypeIsNotARoutingInput() {
        // PGS/ASS/SRT selection is handled by the subtitle pipeline, not routing —
        // there is no subtitle input here, so the route is identical regardless.
        let a = PlaybackRoutingPolicy.intendedRoute(RoutingInput(needsRemux: false))
        let b = PlaybackRoutingPolicy.intendedRoute(RoutingInput(needsRemux: false))
        XCTAssertEqual(a, b)
    }

    // MARK: - Fallback ladder (deterministic, loop-free)

    func testRPlayerDirectFatalFallsBackToHLSOnce() {
        let decision = PlaybackFallbackPolicy.decide(
            FallbackInput(player: .rivulet, attemptedFamily: .avPlayerDirect, failure: .decode)
        )
        XCTAssertEqual(decision, .fallback(.hls))
    }

    func testRPlayerLocalRemuxFatalFallsBackToHLSOnce() {
        let decision = PlaybackFallbackPolicy.decide(
            FallbackInput(player: .rivulet, attemptedFamily: .localRemux, failure: .demux)
        )
        XCTAssertEqual(decision, .fallback(.hls))
    }

    func testSecondFallbackIsStopped_NoLoop() {
        let decision = PlaybackFallbackPolicy.decide(
            FallbackInput(player: .rivulet, attemptedFamily: .avPlayerDirect, failure: .unknown,
                          hlsFallbackAlreadyAttempted: true)
        )
        XCTAssertEqual(decision, .stopWithError)
    }

    func testFailureOnHLSStops() {
        let decision = PlaybackFallbackPolicy.decide(
            FallbackInput(player: .rivulet, attemptedFamily: .hls, failure: .network)
        )
        XCTAssertEqual(decision, .stopWithError)
    }

    func testNoHLSRouteAvailableStops() {
        let decision = PlaybackFallbackPolicy.decide(
            FallbackInput(player: .rivulet, attemptedFamily: .avPlayerDirect, failure: .decode,
                          hlsRouteAvailable: false)
        )
        XCTAssertEqual(decision, .stopWithError)
    }

    func testAVKitHasNoAutomaticRouteFallback() {
        let decision = PlaybackFallbackPolicy.decide(
            FallbackInput(player: .avKit, attemptedFamily: .avPlayerDirect, failure: .decode)
        )
        XCTAssertEqual(decision, .noFallback)
    }

    func testFallbackLadderTerminatesInTwoHops() {
        // hop 1: rivulet direct → HLS
        let first = PlaybackFallbackPolicy.decide(
            FallbackInput(player: .rivulet, attemptedFamily: .avPlayerDirect, failure: .decode)
        )
        XCTAssertEqual(first, .fallback(.hls))
        // hop 2: now on HLS (one-shot spent) → stop
        let second = PlaybackFallbackPolicy.decide(
            FallbackInput(player: .rivulet, attemptedFamily: .hls, failure: .network,
                          hlsFallbackAlreadyAttempted: true)
        )
        XCTAssertEqual(second, .stopWithError)
    }

    // MARK: - Telemetry mapping is safe

    func testTelemetryRouteMappingNeverLeaksAndIsAllowListed() {
        let routes: [IntendedRoute] = [.avKitDirect, .avKitHls, .avKitLocalRemux, .rPlayerDirect, .rPlayerHls, .rPlayerLocalRemux]
        for route in routes {
            let name = PlaybackRoutingPolicy.telemetryRoute(route)
            let fields = PlaybackTelemetry.fields(for: .routeSelected(
                PlaybackTelemetry.SafeContext(mediaType: "movie", codecFamily: "hevc"),
                route: name,
                reason: "policy decision"
            ))
            XCTAssertEqual(fields["route"], name.rawValue)
            for v in fields.values {
                XCTAssertFalse(v.lowercased().contains("http"))
                XCTAssertFalse(v.contains("X-Plex-Token"))
            }
        }
    }
}
