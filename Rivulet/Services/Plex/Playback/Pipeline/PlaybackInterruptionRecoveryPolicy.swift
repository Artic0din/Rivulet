//
//  PlaybackInterruptionRecoveryPolicy.swift
//  Rivulet
//
//  E4-PR5 — pure, deterministic interruption / recovery policy.
//
//  Makes the existing interruption, backgrounding, foregrounding, rebuffer,
//  stall, route-loss and AirPlay-instability recovery DECISIONS explicit and
//  unit-testable. It mirrors today's runtime behaviour exactly and is NOT wired
//  into the live pipeline, so playback behaviour is unchanged by this slice.
//
//  Faithful mirror of:
//   - `UniversalPlayerViewModel.observeAppLifecycle()` — background pauses while
//     playing; foreground keeps it paused (user resumes manually).
//   - `UniversalPlayerViewModel` remux buffer recovery (`keepUp` + rate observers)
//     — auto-resume when the buffer refills while paused/buffering.
//   - `UniversalPlayerViewModel` `timeControlStatus` — waiting → `.buffering`.
//   - `RivuletPlayer.handleSystemRouteChange` / `handleAudioRendererAutoFlush` /
//     `handleAudioOutputConfigurationChange` — reapply audio policy + recover.
//   - `RivuletPlayer.recordAirPlayInstabilityEvent` /
//     `shouldAttemptAirPlayStabilityFallback` — the stereo-fallback / abandon
//     ladder, encoded here as `airPlayInstabilityDecision`.
//   - `DirectPlayPipeline.resume()` dead-read-loop restart.
//   - `AudioRouteDiagnostics` — audio-session interruptions are diagnostics-only
//     on tvOS today (no playback action).
//   - `UniversalPlayerViewModel.retryPlayback()` — user-initiated full restart.
//   - fatal route fallback is delegated to `PlaybackFallbackPolicy` (E4-PR3) so
//     there is a single source of truth and no duplicated fallback logic.
//
//  Watch state is untouched (Epic 1 boundary). No `PlexMetadata` import, no Plex
//  API call. The policy is `nonisolated`, deterministic, loop-free and
//  player-agnostic.
//

import Foundation

// MARK: - Vocabulary

/// What just happened that may require a recovery decision.
nonisolated enum InterruptionSource: Sendable, Equatable {
    /// App entered the background (home/sleep). Does NOT fire for the tvOS
    /// Control Center overlay.
    case appBackgrounded
    /// App returned to the foreground / became active.
    case appForegrounded
    /// `AVAudioSession` interruption began (diagnostics-only on tvOS today).
    case audioSessionInterruptionBegan
    /// `AVAudioSession` interruption ended; `shouldResume` is the system hint
    /// (diagnostics-only on tvOS today).
    case audioSessionInterruptionEnded(shouldResume: Bool)
    /// `AVAudioSession.routeChangeNotification` (e.g. AirPlay device swap).
    case audioRouteChanged
    /// The sample-buffer audio renderer auto-flushed (AirPlay transport reset).
    case audioRendererAutoFlush
    /// The audio output configuration changed.
    case audioOutputConfigurationChanged
    /// A buffer underrun / stall began.
    case bufferUnderrun
    /// The buffer refilled (likely-to-keep-up).
    case bufferRecovered
    /// RPlayer read loop exited after a paused seek and must be restarted.
    case readLoopDied
    /// A fatal playback failure occurred; the route-fallback ladder applies.
    case fatalError(PlaybackTelemetry.FailureCategory)
    /// The user explicitly asked to retry after an error.
    case userRetry
}

/// Coarse playback phase (mirrors `PlayerProtocol` states, decoupled from it).
nonisolated enum PlaybackPhase: String, Sendable, Equatable {
    case idle, loading, playing, paused, buffering, ended, failed
}

/// Already-derived inputs for an interruption decision (no live object access).
nonisolated struct InterruptionInput: Sendable, Equatable {
    var source: InterruptionSource
    /// The player presenting playback.
    var player: PlaybackPlayer
    /// Current coarse playback phase.
    var phase: PlaybackPhase
    /// Playback was auto-paused because the app went to the background.
    var pausedDueToBackground: Bool = false
    /// The AVPlayer local-remux path (the only path with `keepUp` auto-resume).
    var isRemux: Bool = false
    // Fatal-path delegation inputs (forwarded to `PlaybackFallbackPolicy`):
    var attemptedFamily: RouteFamily = .hls
    var hlsFallbackAlreadyAttempted: Bool = false
    var hlsRouteAvailable: Bool = true

    init(
        source: InterruptionSource,
        player: PlaybackPlayer,
        phase: PlaybackPhase,
        pausedDueToBackground: Bool = false,
        isRemux: Bool = false,
        attemptedFamily: RouteFamily = .hls,
        hlsFallbackAlreadyAttempted: Bool = false,
        hlsRouteAvailable: Bool = true
    ) {
        self.source = source
        self.player = player
        self.phase = phase
        self.pausedDueToBackground = pausedDueToBackground
        self.isRemux = isRemux
        self.attemptedFamily = attemptedFamily
        self.hlsFallbackAlreadyAttempted = hlsFallbackAlreadyAttempted
        self.hlsRouteAvailable = hlsRouteAvailable
    }
}

/// The recovery action to take. Each case maps to an observable behaviour that
/// already exists in the live pipeline.
nonisolated enum RecoveryDecision: Sendable, Equatable {
    /// Do nothing (the interruption is irrelevant in the current phase).
    case noAction
    /// Diagnostics only — log the event but take no playback action (tvOS
    /// audio-session interruptions today).
    case logOnly
    /// Pause and leave it paused; the user must resume (background/foreground).
    case pauseAwaitingUser
    /// Resume playback immediately (remux buffer refilled).
    case resumeImmediately
    /// Surface the buffering state (a stall began).
    case showBuffering
    /// Reapply the audio policy and recover the renderer in place — no route or
    /// player change (RPlayer route change / auto-flush / output change).
    case recoverAudio
    /// Rebuild the player on the SAME route at the current time (RPlayer
    /// AirPlay stereo stability fallback; dead read-loop restart with preroll).
    case rebuildPlayer
    /// Tear down and restart from scratch (user-initiated retry).
    case retryPlayback
    /// Fall back to the given route family at the current time (one-shot,
    /// delegated to `PlaybackFallbackPolicy`).
    case fallbackRoute(RouteFamily)
    /// Stop and surface a calm, redacted user-facing error.
    case showPlaybackError
    /// Give up on automatic recovery and report failure (AirPlay hard-unstable).
    case abandonRecovery
}

// MARK: - Policy

nonisolated enum PlaybackInterruptionRecoveryPolicy {

    /// The recovery decision for a single interruption. Deterministic and
    /// loop-free: fatal failures delegate to the one-shot `PlaybackFallbackPolicy`
    /// and every other branch resolves in a single step.
    static func decide(_ input: InterruptionInput) -> RecoveryDecision {
        switch input.source {
        case .appBackgrounded:
            // Pause only when actually playing; otherwise nothing to do.
            return input.phase == .playing ? .pauseAwaitingUser : .noAction

        case .appForegrounded:
            // Returning from a background-induced pause stays paused — the user
            // resumes manually. If we did not auto-pause, do nothing.
            return input.pausedDueToBackground ? .pauseAwaitingUser : .noAction

        case .audioSessionInterruptionBegan, .audioSessionInterruptionEnded:
            // tvOS: handled by diagnostics logging only — no playback action.
            return .logOnly

        case .audioRouteChanged, .audioRendererAutoFlush:
            // Reapply the audio policy and recover the renderer in place.
            return .recoverAudio

        case .audioOutputConfigurationChanged:
            // Only acts while playing (mirrors the `guard isPlaying` in RPlayer).
            return input.phase == .playing ? .recoverAudio : .noAction

        case .bufferUnderrun:
            return .showBuffering

        case .bufferRecovered:
            // Only the remux path self-resumes, and only from paused/buffering.
            if input.isRemux, input.phase == .paused || input.phase == .buffering {
                return .resumeImmediately
            }
            return .noAction

        case .readLoopDied:
            // Restart the read loop with preroll (a same-route rebuild).
            return .rebuildPlayer

        case .userRetry:
            return .retryPlayback

        case .fatalError(let category):
            // Single source of truth: delegate to the E4-PR3 fallback policy.
            let fallback = PlaybackFallbackPolicy.decide(
                FallbackInput(
                    player: input.player,
                    attemptedFamily: input.attemptedFamily,
                    failure: category,
                    hlsFallbackAlreadyAttempted: input.hlsFallbackAlreadyAttempted,
                    hlsRouteAvailable: input.hlsRouteAvailable
                )
            )
            switch fallback {
            case .fallback(let family): return .fallbackRoute(family)
            case .stopWithError:        return .showPlaybackError
            case .noFallback:           return .showPlaybackError
            }
        }
    }

    // MARK: - AirPlay instability ladder

    /// Accumulated AirPlay renderer-instability counts and gating flags. Mirrors
    /// the state `RivuletPlayer.recordAirPlayInstabilityEvent` evaluates.
    nonisolated struct AirPlayInstabilityInput: Sendable, Equatable {
        var autoFlushCount: Int
        var outputRecoveryCount: Int
        var rendererFailureCount: Int
        /// Already fell back to the stereo policy (`airPlayStabilityFallbackToStereo`).
        var alreadyFellBackToStereo: Bool
        /// A stability fallback is currently in flight.
        var fallbackInFlight: Bool
        /// The stereo fallback policy differs from the default policy, so a
        /// fallback would actually change behaviour (`defaultPolicy != fallback`).
        var stereoPolicyDiffers: Bool

        init(
            autoFlushCount: Int = 0,
            outputRecoveryCount: Int = 0,
            rendererFailureCount: Int = 0,
            alreadyFellBackToStereo: Bool = false,
            fallbackInFlight: Bool = false,
            stereoPolicyDiffers: Bool = true
        ) {
            self.autoFlushCount = autoFlushCount
            self.outputRecoveryCount = outputRecoveryCount
            self.rendererFailureCount = rendererFailureCount
            self.alreadyFellBackToStereo = alreadyFellBackToStereo
            self.fallbackInFlight = fallbackInFlight
            self.stereoPolicyDiffers = stereoPolicyDiffers
        }

        var totalCount: Int { autoFlushCount + outputRecoveryCount + rendererFailureCount }
    }

    /// The AirPlay-instability recovery decision, mirroring
    /// `recordAirPlayInstabilityEvent` exactly:
    ///   1. If a stereo fallback is still available (not already used, not in
    ///      flight, and it would change the policy) AND the lower instability
    ///      threshold is crossed (`rendererFailure≥1 || autoFlush≥2 ||
    ///      outputRecovery≥2 || total≥3`) → rebuild on the same route in stereo.
    ///   2. Else if the hard-unstable threshold is crossed (`autoFlush≥3 ||
    ///      outputRecovery≥3 || rendererFailure≥2 || total≥5`) → abandon recovery
    ///      and report failure.
    ///   3. Otherwise → recover the renderer in place.
    ///
    /// Monotone in the counts: once the stereo fallback is spent, further
    /// instability can only escalate to `abandonRecovery`, so no loop is possible.
    static func airPlayInstabilityDecision(_ input: AirPlayInstabilityInput) -> RecoveryDecision {
        let total = input.totalCount

        let canTryStereoFallback =
            !input.alreadyFellBackToStereo &&
            !input.fallbackInFlight &&
            input.stereoPolicyDiffers
        let crossesFallbackThreshold =
            input.rendererFailureCount >= 1 ||
            input.autoFlushCount >= 2 ||
            input.outputRecoveryCount >= 2 ||
            total >= 3
        if canTryStereoFallback && crossesFallbackThreshold {
            return .rebuildPlayer
        }

        let isHardUnstable =
            input.autoFlushCount >= 3 ||
            input.outputRecoveryCount >= 3 ||
            input.rendererFailureCount >= 2 ||
            total >= 5
        if isHardUnstable {
            return .abandonRecovery
        }

        return .recoverAudio
    }

    // MARK: - Telemetry mapping (pure; emission deferred to wiring)

    /// Maps a recovery decision to a safe telemetry event (E4-PR2 contract), or
    /// `nil` when the decision is not worth an event. Only the safe, allow-listed
    /// `Event` cases are produced — no URLs/tokens can be expressed. Pure: live
    /// emission is adopted by the future wiring slice (see the policy doc).
    static func telemetryEvent(
        for decision: RecoveryDecision,
        context: PlaybackTelemetry.SafeContext
    ) -> PlaybackTelemetry.Event? {
        switch decision {
        case .showBuffering:
            return .stall(context)
        case .resumeImmediately:
            return .recovered(context, result: .recovered)
        case .rebuildPlayer, .fallbackRoute:
            return .recovered(context, result: .fellBack)
        case .abandonRecovery, .showPlaybackError:
            return .recovered(context, result: .failed)
        case .noAction, .logOnly, .pauseAwaitingUser, .recoverAudio, .retryPlayback:
            return nil
        }
    }
}
