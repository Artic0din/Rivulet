//
//  DiscoverPresentation.swift
//  Rivulet
//
//  E3-PR5 — deterministic Discover render-state resolution.
//
//  DiscoverView previously rendered hero + curated sections directly off the
//  view model with only a `loading` flag and no empty/loading surface, so a
//  Discover page with no resolved content showed a blank screen. This pure
//  policy maps the view model's signals to a `RenderStatePhase` so the view can
//  present a calm loading/empty surface, reusing the Epic 2 `ContentStateView`.
//
//  Discover has no surfaced error channel (TMDB section fetches degrade to empty
//  results rather than throwing), so the phase space is loading / content /
//  empty — content always wins, mirroring `RenderStateResolver`'s precedence.
//
//  Pure and `nonisolated` so it is unit-testable and callable from any context.
//

import Foundation

nonisolated enum DiscoverPresentation {
    /// Resolves the Discover surface phase. Content present always wins so a
    /// populated page never flips to loading/empty during a background refresh.
    static func phase(isLoading: Bool, hasContent: Bool) -> RenderStatePhase {
        if hasContent { return .content }
        if isLoading { return .loading }
        return .empty
    }
}
