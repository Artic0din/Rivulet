//
//  FocusRestorationPolicy.swift
//  Rivulet
//
//  E2-PR3 — pure, testable focus-identity and restoration rules for Home.
//
//  Centralises the "restore focus across a content refresh, but never to an item
//  that no longer exists" rule that Home rows previously expressed inline. Pure
//  functions (no SwiftUI, no global state) so the rules are unit-testable and
//  shared by Home rows now and by Hero / Continue Watching / sidebar work later.
//
//  Focus identities are compared as opaque full strings (e.g. "<rowID>:<itemID>")
//  against the set of currently-valid identities. No substring parsing — robust
//  to rowIDs or itemIDs that themselves contain the ":" separator.
//

import Foundation

/// Builds the canonical focus identity string for a row item.
enum FocusID {
    /// Canonical focus identity: `"<rowID>:<itemID>"`. Treat the result as opaque;
    /// compare whole strings rather than parsing it back apart.
    static func make(rowID: String, itemID: String) -> String {
        "\(rowID):\(itemID)"
    }
}

/// Deterministic focus-restoration rules. All functions are pure.
enum FocusRestorationPolicy {
    /// After a content refresh, keep the previously-focused identity only if it is
    /// still a valid target; otherwise return `nil` so the focus engine picks a
    /// fresh default instead of pointing at a vanished item (which strands focus).
    ///
    /// - Parameters:
    ///   - saved: the focus identity captured before the refresh (may be nil).
    ///   - validFocusIDs: focus identities present after the refresh.
    static func restoredFocusID(saved: String?, validFocusIDs: Set<String>) -> String? {
        guard let saved, validFocusIDs.contains(saved) else { return nil }
        return saved
    }

    /// Entry / initial focus target for a section: the remembered identity if it
    /// is still valid, otherwise the first available identity, otherwise nil
    /// (nothing focusable). Order of `orderedValidFocusIDs` defines "first".
    static func entryFocusID(remembered: String?, orderedValidFocusIDs: [String]) -> String? {
        if let remembered, orderedValidFocusIDs.contains(remembered) {
            return remembered
        }
        return orderedValidFocusIDs.first
    }
}
