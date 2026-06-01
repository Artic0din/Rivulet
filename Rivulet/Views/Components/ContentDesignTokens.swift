//
//  ContentDesignTokens.swift
//  Rivulet
//
//  E3-PR2 — canonical content design language.
//
//  Rivulet's content surfaces (rows, cards, detail, preview) share one Glass
//  aesthetic, but the defining values — focus opacities, focus/press scales,
//  spring timings, corner radii, shadow depth, and the metadata type ramp —
//  were duplicated as inline literals across `GlassRowStyle` and many views.
//  That made the look impossible to keep consistent or to evolve in one place.
//
//  This is the semantic token layer that sits ON TOP of `ScaledDimensions`
//  (which already owns physical sizes). Every value here is seeded to the exact
//  literal it replaces, so adopting a token is behavior-identical; unit tests
//  pin the seeds so an accidental drift is caught. `nonisolated` so the tokens
//  are usable from any context (the project defaults types to `@MainActor`).
//
//  Scope: content design language only. No physical sizing (that stays in
//  `ScaledDimensions`), no Apple asset/trade-dress cloning, no behavior change.
//

import SwiftUI

nonisolated enum ContentDesignTokens {

    /// Focus/emphasis opacities for the Glass surfaces.
    enum Opacity {
        /// Glass row fill — focused vs resting.
        static let glassFillFocused: Double = 0.18
        static let glassFillResting: Double = 0.08
        /// Glass row border — focused vs resting.
        static let glassBorderFocused: Double = 0.30
        static let glassBorderResting: Double = 0.10
        /// Glass row focus shadow.
        static let glassShadowFocused: Double = 0.10
        /// Standalone button (App Store style) resting fill.
        static let buttonFillResting: Double = 0.15
        /// Inline action button resting fill — primary vs secondary.
        static let actionFillPrimaryResting: Double = 0.20
        static let actionFillSecondaryResting: Double = 0.12
        /// Inline action button resting stroke.
        static let actionStrokeResting: Double = 0.20
    }

    /// Focus/press scale factors. Distinct profiles for rows vs controls.
    enum Scale {
        /// Row-level focus emphasis (Elegant Restraint — ~2%).
        static let rowFocused: CGFloat = 1.02
        /// Inline action-button focus emphasis.
        static let actionFocused: CGFloat = 1.08
        /// Standalone button focus emphasis.
        static let buttonFocused: CGFloat = 1.10
        /// Pressed feedback for any control.
        static let pressed: CGFloat = 0.95
        /// Resting (no emphasis).
        static let resting: CGFloat = 1.0
    }

    /// Canonical motion. Subtle, natural springs — no overshoot/bounce.
    enum Motion {
        /// Row focus transition.
        static let rowFocus: Animation = .spring(response: 0.3, dampingFraction: 0.7)
        /// Control (button) focus transition.
        static let controlFocus: Animation = .spring(response: 0.25, dampingFraction: 0.8)
        /// Press feedback transition.
        static let press: Animation = .spring(response: 0.15, dampingFraction: 0.9)
    }

    /// Corner radii and depth for Glass surfaces.
    enum Shape {
        static let cornerRadius: CGFloat = 16
        static let shadowRadius: CGFloat = 8
        static let shadowY: CGFloat = 2
    }

    /// Semantic metadata type ramp for content surfaces, expressed as aliases
    /// over `ScaledDimensions` so there is a single source of physical size.
    /// Ordered large → small; unit-tested to stay monotonic.
    enum TypeRamp {
        static let hero: CGFloat = ScaledDimensions.heroTitleSize       // 56
        static let section: CGFloat = ScaledDimensions.sectionTitleSize // 30
        static let cardTitle: CGFloat = ScaledDimensions.posterTitleSize // 24
        static let cardSubtitle: CGFloat = ScaledDimensions.posterSubtitleSize // 19
    }
}
