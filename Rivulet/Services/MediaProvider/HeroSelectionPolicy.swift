//
//  HeroSelectionPolicy.swift
//  Rivulet
//
//  E2-PR4 — deterministic, testable selection of the Home hero's item set from
//  the available home hubs. Pure logic with no SwiftUI, networking, or Plex
//  client coupling: callers map their hubs into `HeroHubCandidate` values and
//  this policy applies a fixed priority.
//
//  Priority (Apple-TV-like, favouring resumable content first):
//    1. active Continue Watching
//    2. featured / curated (recommended, promoted, featured, spotlight)
//    3. recently added
//    4. any other non-empty hub (deterministic first)
//
//  The hero is never empty when any candidate has at least one item with a
//  stable identity; only a total absence of content yields an empty result,
//  which the Home RenderState empty state then handles.
//

import Foundation

/// The role a home hub plays for hero selection.
enum HeroHubKind: Equatable {
    case continueWatching
    case curated
    case recentlyAdded
    case other
}

/// A home hub reduced to what hero selection needs: its role and its items.
struct HeroHubCandidate {
    let kind: HeroHubKind
    let identifier: String?
    let items: [PlexMetadata]
}

enum HeroSelectionPolicy {
    /// Fixed priority order. Deterministic and stable.
    static let priority: [HeroHubKind] = [.continueWatching, .curated, .recentlyAdded, .other]

    /// Select the hero item set from candidate hubs.
    ///
    /// Walks the priority order and returns the first candidate of each kind
    /// whose identity-bearing items are non-empty, capped at `cap`. If no
    /// prioritised kind yields content, falls back to the first candidate (in
    /// the order given) with identity-bearing items. Returns `[]` only when no
    /// candidate has a usable item.
    static func select(from candidates: [HeroHubCandidate], cap: Int) -> [PlexMetadata] {
        guard cap > 0 else { return [] }

        for kind in priority {
            for candidate in candidates where candidate.kind == kind {
                let usable = identityBearing(candidate.items, cap: cap)
                if !usable.isEmpty { return usable }
            }
        }

        // Fallback: first candidate of any kind with usable items, preserving
        // the caller's order.
        for candidate in candidates {
            let usable = identityBearing(candidate.items, cap: cap)
            if !usable.isEmpty { return usable }
        }

        return []
    }

    /// Items that carry a stable identity (`ratingKey`), capped. Hero cards key
    /// on `ratingKey`, so items without one cannot be presented.
    private static func identityBearing(_ items: [PlexMetadata], cap: Int) -> [PlexMetadata] {
        Array(items.filter { $0.ratingKey != nil }.prefix(cap))
    }
}
