//
//  HeroRotationPolicy.swift
//  Rivulet
//
//  Pure, unit-tested decision layer for the home hero's auto-rotation.
//
//  The hero shows several eligible items (selected by `HeroSelectionPolicy`) but
//  previously only advanced when the user pressed Next. This policy decides
//  WHETHER auto-rotation may run for a given state and WHAT the next index is.
//  It holds no timers, view, or async state — the view drives a `Task.sleep`
//  loop and consults this for the gate + interval. `nonisolated` so it is
//  callable and testable from any context.
//
//  No playback, provider, auth, token, or logging involvement — index math and
//  booleans only.
//

import Foundation

nonisolated enum HeroRotationPolicy {
    /// Auto-rotation cadence. Inside the requested 8–12 s window; deterministic.
    static let intervalSeconds: Int = 10

    /// Whether auto-rotation should run right now.
    ///   - itemCount: number of eligible hero items (need > 1 to rotate).
    ///   - isHeroFocused: a hero control (Play/More Info/etc.) is focused — pause
    ///     so the slide does not shift under the user.
    ///   - isBusy: a hero action is resolving (e.g. play target lookup) — pause.
    ///   - isActive: the home hero is the active, visible surface (no detail /
    ///     preview / player / resume prompt presented, app is foreground).
    static func shouldRotate(
        itemCount: Int,
        isHeroFocused: Bool,
        isBusy: Bool,
        isActive: Bool
    ) -> Bool {
        guard itemCount > 1 else { return false }
        guard isActive else { return false }
        guard !isHeroFocused else { return false }
        guard !isBusy else { return false }
        return true
    }

    /// Next index, wrapping to the start. Returns 0 for an empty set.
    static func nextIndex(current: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let next = current + 1
        return next >= count ? 0 : next
    }
}
