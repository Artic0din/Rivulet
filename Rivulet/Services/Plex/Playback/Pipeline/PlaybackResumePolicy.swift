//
//  PlaybackResumePolicy.swift
//  Rivulet
//
//  E4-PR4 — pure, deterministic resume / start-offset policy.
//
//  Makes the existing resume decision explicit and testable so later route
//  integration (E4-PR6) can apply resume consistently across AVKit, RPlayer, HLS,
//  local remux, and the post-crash fallback. It mirrors today's behaviour exactly
//  and is NOT wired into the live pipeline, so runtime resume behaviour is
//  unchanged.
//
//  Faithful mirror of:
//   - `MediaDetailView.presentPlay(for:launch:)` — prompt vs auto-resume.
//   - the start-offset computation in the play launch closure
//     (`playFromBeginning ? nil : (offset > 0 ? offset : nil)`).
//   - `MediaItem.isInProgress` — `offset > 0 && offset/duration < 0.98`.
//
//  Watch state is CONSUME-ONLY here: the policy reads already-resolved offsets as
//  inputs and writes nothing. It does not touch `PlexProgressReporter`,
//  `PlexWatchStateRequestFactory`, the provider contract, or timeline reporting
//  (Epic 1 boundary). No `PlexMetadata` import, no Plex API call. Offsets are in
//  milliseconds for unit clarity.
//

import Foundation

nonisolated enum PlaybackResumePolicy {

    /// Items at or beyond this fraction of their duration are NOT "in progress"
    /// (mirrors `MediaItem.isInProgress`). Near-end gates *prompt eligibility*
    /// only; it does not by itself rewrite the resume offset (the player engine
    /// clamps), matching current behaviour.
    static let nearEndThreshold: Double = 0.98

    nonisolated struct ResumeInput: Sendable, Equatable {
        /// Stored view offset in ms (0 = not started).
        var viewOffsetMs: Int
        /// Total duration in ms (0/unknown tolerated).
        var durationMs: Int
        /// `promptResumeOrRestart` user setting.
        var promptEnabled: Bool
        /// Explicit "Play from Beginning" (restart) request.
        var explicitRestart: Bool
        /// Live TV — never resumes.
        var isLive: Bool
        /// Trailer / extra — never resumes.
        var isTrailer: Bool

        init(
            viewOffsetMs: Int,
            durationMs: Int = 0,
            promptEnabled: Bool = false,
            explicitRestart: Bool = false,
            isLive: Bool = false,
            isTrailer: Bool = false
        ) {
            self.viewOffsetMs = viewOffsetMs
            self.durationMs = durationMs
            self.promptEnabled = promptEnabled
            self.explicitRestart = explicitRestart
            self.isLive = isLive
            self.isTrailer = isTrailer
        }
    }

    nonisolated enum ResumeDecision: Sendable, Equatable {
        /// Start at 0 (no resume seek).
        case startAtBeginning
        /// Auto-resume at the given offset.
        case resume(offsetMs: Int)
        /// Show the resume/restart prompt seeded with the given offset; the
        /// concrete start is resolved by `resolvePromptChoice` after the user picks.
        case prompt(offsetMs: Int)
    }

    /// Mirrors `MediaItem.isInProgress`: started, not finished, below near-end.
    static func isInProgress(viewOffsetMs: Int, durationMs: Int) -> Bool {
        guard durationMs > 0, viewOffsetMs > 0 else { return false }
        return Double(viewOffsetMs) / Double(durationMs) < nearEndThreshold
    }

    /// The start decision before any prompt — mirrors `presentPlay`. Live/trailer
    /// and explicit restart never resume; a prompt fires only when the setting is
    /// on AND the item is genuinely in progress; otherwise we auto-resume when a
    /// real offset exists, else start at the beginning.
    static func decide(_ input: ResumeInput) -> ResumeDecision {
        if input.isLive || input.isTrailer { return .startAtBeginning }
        if input.explicitRestart { return .startAtBeginning }
        if input.promptEnabled,
           input.viewOffsetMs > 0,
           isInProgress(viewOffsetMs: input.viewOffsetMs, durationMs: input.durationMs) {
            return .prompt(offsetMs: input.viewOffsetMs)
        }
        return input.viewOffsetMs > 0 ? .resume(offsetMs: input.viewOffsetMs) : .startAtBeginning
    }

    /// Resolves a `.prompt` once the user chooses (restart → beginning, else resume).
    static func resolvePromptChoice(offsetMs: Int, userChoseRestart: Bool) -> ResumeDecision {
        userChoseRestart ? .startAtBeginning : .resume(offsetMs: offsetMs)
    }

    /// Single source of truth for the seek offset to apply at start: nil means
    /// "start at 0, no explicit seek". A `.prompt` yields nil here (the seek is
    /// decided after the choice resolves). Centralising this is what lets a future
    /// integration avoid duplicate seeks across routes.
    static func seekOffsetMs(for decision: ResumeDecision) -> Int? {
        switch decision {
        case .startAtBeginning: return nil
        case .resume(let ms):   return ms
        case .prompt:           return nil
        }
    }

    /// Mirrors the play launch closure's offset computation:
    /// `playFromBeginning ? nil : (offset > 0 ? offset : nil)`.
    static func startOffsetMs(playFromBeginning: Bool, viewOffsetMs: Int) -> Int? {
        if playFromBeginning { return nil }
        return viewOffsetMs > 0 ? viewOffsetMs : nil
    }
}
