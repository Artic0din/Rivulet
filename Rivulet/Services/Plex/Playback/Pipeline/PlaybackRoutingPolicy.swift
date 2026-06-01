//
//  PlaybackRoutingPolicy.swift
//  Rivulet
//
//  E4-PR3 — pure, deterministic playback routing + fallback policies.
//
//  These policies make the existing routing/fallback DECISIONS explicit and
//  testable ahead of the AVKit-first default flip (E4-PR6). AVKit-first has been
//  ratified by the Project Owner, but THIS slice does NOT flip the default: the
//  `avKitFirst` input defaults to `false`, so every decision here mirrors the
//  current runtime exactly (`ContentRouter.plan` + the player choice in
//  `UniversalPlayerViewModel.startPlayback`). The policies are standalone and are
//  NOT yet wired into the live pipeline, so runtime behaviour is unchanged.
//
//  Decoupled from `PlexMetadata`: inputs are already-derived, typed values, so
//  the decisions are pure and unit-testable. A future slice (E4-PR6) populates
//  `RoutingInput` from the same metadata `ContentRouter` already inspects and
//  flips `avKitFirst` behind a flag.
//

import Foundation

// MARK: - Vocabulary

/// Which player presents the route.
nonisolated enum PlaybackPlayer: String, Sendable, Equatable {
    case rivulet   // RPlayer (FFmpeg + AVSampleBuffer)
    case avKit     // AVPlayer (AVPlayerViewController)
}

/// The route family `ContentRouter` produces (independent of the player).
nonisolated enum RouteFamily: String, Sendable, Equatable {
    case avPlayerDirect
    case localRemux
    case hls
}

/// The combined player × family decision (the brief's typed outputs).
nonisolated enum IntendedRoute: String, Sendable, Equatable {
    case avKitDirect
    case avKitHls
    case avKitLocalRemux
    case rPlayerDirect
    case rPlayerHls
    case rPlayerLocalRemux
}

/// Already-derived routing inputs (populated from the same metadata
/// `ContentRouter` inspects; no provider call here).
nonisolated struct RoutingInput: Sendable, Equatable {
    /// Live TV always routes to HLS.
    var isLiveTV: Bool = false
    /// Forced HLS (post-crash fallback request).
    var forceHLS: Bool = false
    /// Source video codec has no Apple TV decoder (MPEG-2/VC-1/VP9/AV1) or is
    /// HLG HDR — must server-transcode, and only AVPlayer consumes that HLS.
    var videoRequiresTranscode: Bool = false
    /// FFmpeg demuxer available (RPlayer / local remux possible).
    var ffmpegAvailable: Bool = true
    /// Content needs remux (non-native container / non-native audio).
    var needsRemux: Bool = false
    /// Dolby Vision P7/P8.6 → needs RPU conversion (forces a remux route).
    var needsDVConversion: Bool = false
    /// A direct-play URL can be built (Media/Part key present).
    var canBuildDirectRoute: Bool = true
    /// `useApplePlayer` user setting (biases toward AVPlayer paths).
    var useApplePlayer: Bool = false
    /// AVKit-first default. **Defaults false** — true is the E4-PR6 staged flip.
    var avKitFirst: Bool = false

    init(
        isLiveTV: Bool = false,
        forceHLS: Bool = false,
        videoRequiresTranscode: Bool = false,
        ffmpegAvailable: Bool = true,
        needsRemux: Bool = false,
        needsDVConversion: Bool = false,
        canBuildDirectRoute: Bool = true,
        useApplePlayer: Bool = false,
        avKitFirst: Bool = false
    ) {
        self.isLiveTV = isLiveTV
        self.forceHLS = forceHLS
        self.videoRequiresTranscode = videoRequiresTranscode
        self.ffmpegAvailable = ffmpegAvailable
        self.needsRemux = needsRemux
        self.needsDVConversion = needsDVConversion
        self.canBuildDirectRoute = canBuildDirectRoute
        self.useApplePlayer = useApplePlayer
        self.avKitFirst = avKitFirst
    }
}

// MARK: - Routing policy

nonisolated enum PlaybackRoutingPolicy {

    /// Which player presents playback. Mirrors `UniversalPlayerViewModel`:
    /// RPlayer unless `useApplePlayer` is set OR the video must be transcoded
    /// (only AVPlayer consumes the transcoded HLS end-to-end). `avKitFirst`
    /// (default false) is the future flip — when true, AVKit is the default.
    static func player(_ input: RoutingInput) -> PlaybackPlayer {
        if input.useApplePlayer || input.videoRequiresTranscode || input.avKitFirst {
            return .avKit
        }
        return .rivulet
    }

    /// `useLocalRemux` as `UniversalPlayerViewModel` derives it: the RPlayer path
    /// always handles remux locally (`true`); the AVPlayer path uses local remux
    /// only when `useApplePlayer` is off.
    static func effectiveUseLocalRemux(_ input: RoutingInput) -> Bool {
        player(input) == .rivulet ? true : !input.useApplePlayer
    }

    /// Route family + reasons, mirroring `ContentRouter.plan`'s branch order
    /// exactly. `useLocalRemux` is supplied (so this is a faithful mirror of the
    /// router given a context); `intendedRoute(_:)` derives it per the UPVM rule.
    static func routeFamily(_ input: RoutingInput, useLocalRemux: Bool) -> (family: RouteFamily, reasons: [String]) {
        if input.isLiveTV { return (.hls, ["live_tv_requires_hls"]) }
        if input.forceHLS { return (.hls, ["force_hls_requested"]) }
        if input.videoRequiresTranscode { return (.hls, ["video_requires_transcode"]) }

        if !input.ffmpegAvailable {
            if !input.needsRemux, input.canBuildDirectRoute {
                return (.avPlayerDirect, ["ffmpeg_unavailable_but_native_container"])
            }
            return (.hls, ["ffmpeg_unavailable"])
        }

        if !input.needsRemux, input.canBuildDirectRoute {
            return (.avPlayerDirect, ["native_direct_play"])
        }

        if input.needsRemux, useLocalRemux || input.needsDVConversion, input.canBuildDirectRoute {
            return (.localRemux, [input.needsDVConversion ? "local_remux_dv_conversion" : "local_remux_user_enabled"])
        }

        if input.needsRemux {
            return (.hls, ["plex_server_remux"])
        }

        return (.hls, ["fallback_to_hls"])
    }

    /// The combined player × family decision.
    static func intendedRoute(_ input: RoutingInput) -> IntendedRoute {
        let chosenPlayer = player(input)
        let family = routeFamily(input, useLocalRemux: effectiveUseLocalRemux(input)).family
        switch (chosenPlayer, family) {
        case (.avKit, .avPlayerDirect): return .avKitDirect
        case (.avKit, .localRemux):     return .avKitLocalRemux
        case (.avKit, .hls):            return .avKitHls
        case (.rivulet, .avPlayerDirect): return .rPlayerDirect
        case (.rivulet, .localRemux):     return .rPlayerLocalRemux
        case (.rivulet, .hls):            return .rPlayerHls
        }
    }

    /// Anonymised route name for telemetry (`PlaybackTelemetry`). Never a URL.
    static func telemetryRoute(_ route: IntendedRoute) -> PlaybackTelemetry.RouteName {
        switch route {
        case .avKitDirect:      return .avPlayerDirect
        case .avKitLocalRemux:  return .localRemux
        case .avKitHls:         return .hls
        case .rPlayerDirect:    return .rplayerDirectPlay
        case .rPlayerLocalRemux: return .localRemux
        case .rPlayerHls:       return .hls
        }
    }
}

// MARK: - Fallback policy

/// What to do after a playback attempt fails.
nonisolated enum PlaybackFallbackDecision: Sendable, Equatable {
    /// Fall back to the given route family at the current playback time.
    case fallback(RouteFamily)
    /// Stop and surface a calm, redacted user-facing error.
    case stopWithError
    /// No automatic fallback for this player/route (current AVKit behaviour).
    case noFallback
}

nonisolated struct FallbackInput: Sendable, Equatable {
    /// The player that just failed.
    var player: PlaybackPlayer
    /// The route family that just failed.
    var attemptedFamily: RouteFamily
    /// Classification of the failure.
    var failure: PlaybackTelemetry.FailureCategory
    /// Whether the one-shot HLS fallback was already used (loop guard).
    var hlsFallbackAlreadyAttempted: Bool = false
    /// Whether an HLS route is available to fall back to.
    var hlsRouteAvailable: Bool = true

    init(
        player: PlaybackPlayer,
        attemptedFamily: RouteFamily,
        failure: PlaybackTelemetry.FailureCategory,
        hlsFallbackAlreadyAttempted: Bool = false,
        hlsRouteAvailable: Bool = true
    ) {
        self.player = player
        self.attemptedFamily = attemptedFamily
        self.failure = failure
        self.hlsFallbackAlreadyAttempted = hlsFallbackAlreadyAttempted
        self.hlsRouteAvailable = hlsRouteAvailable
    }
}

nonisolated enum PlaybackFallbackPolicy {
    /// Deterministic, loop-free fallback decision mirroring current behaviour:
    /// an RPlayer (rivulet) fatal falls back to HLS exactly once; once that
    /// one-shot is used (or we are already on HLS, or no HLS route exists) it
    /// stops with an error. The AVKit path has no automatic route fallback
    /// today (user-initiated retry only). There is never more than one
    /// fallback hop, so no retry storm / infinite loop is possible.
    static func decide(_ input: FallbackInput) -> PlaybackFallbackDecision {
        // Already on the terminal route — nowhere safe to fall back to.
        if input.attemptedFamily == .hls { return .stopWithError }
        // One-shot fallback already spent, or no HLS available.
        if input.hlsFallbackAlreadyAttempted || !input.hlsRouteAvailable {
            return .stopWithError
        }
        switch input.player {
        case .rivulet:
            // RPlayer demux/decode/runtime/unsupported/network fatal → HLS once.
            return .fallback(.hls)
        case .avKit:
            // No automatic AVKit route fallback in current behaviour.
            return .noFallback
        }
    }
}
