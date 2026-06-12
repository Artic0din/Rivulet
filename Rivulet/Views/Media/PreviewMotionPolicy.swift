//
//  PreviewMotionPolicy.swift
//  Rivulet
//
//  E3-PR3 — Reduce Motion behaviour for the row-preview transitions.
//
//  The preview overlay drives its structural transitions (entry morph, paging
//  slide, expand, collapse) with explicit `Animation` constants. It had no
//  Reduce Motion handling, so users with that accessibility setting still saw
//  full motion. This pure policy maps a base animation to the effective one:
//  with Reduce Motion enabled the transition is applied *without* animation —
//  the state still changes instantly, so no information or destination is lost,
//  satisfying the matrix rule "critical info survives Reduce Motion".
//
//  Pure and `nonisolated` so it is unit-testable and callable from anywhere.
//  It changes only how a transition is animated, never whether it happens.
//

import SwiftUI

nonisolated enum PreviewMotionPolicy {
    /// The animation to use for a structural preview transition. Returns `nil`
    /// (apply instantly, no animation) when Reduce Motion is enabled, otherwise
    /// the provided base animation.
    static func animation(_ base: Animation, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : base
    }

    /// Whether continuous/secondary motion (paging parallax, vignette drift)
    /// should run. Suppressed under Reduce Motion.
    static func allowsContinuousMotion(reduceMotion: Bool) -> Bool {
        !reduceMotion
    }
}
