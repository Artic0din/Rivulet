//
//  SidebarNavigationPolicy.swift
//  Rivulet
//
//  E2-PR6 — deterministic top-level navigation decisions for the sidebar.
//
//  The sidebar's tab-selection rules were previously expressed as inline
//  guards inside the `TabView` selection binding and several `onChange`
//  handlers in `TVSidebarView`. That made the behavior hard to reason about
//  and impossible to unit test. This policy extracts the pure decisions —
//  whether a requested tab change is honored, and where selection should fall
//  back when a visible tab becomes invalid — so navigation is deterministic
//  and verifiable without driving the SwiftUI focus engine.
//
//  This is policy only. It does not own focus restoration, the sidebar focus
//  guard, or any view state; `TVSidebarView` remains the single place those
//  effects are applied. No custom navigation engine is introduced.
//

import Foundation

/// The outcome of a requested sidebar tab change.
/// `nonisolated`: pure value result, comparable from any context.
nonisolated enum SidebarSelectionOutcome: Equatable {
    /// Honor the change: store `tab` as the selected tab.
    case select(SidebarTab)
    /// The account row was activated with multiple profiles available:
    /// present the profile switcher and leave selection unchanged.
    case presentProfileSwitcher
    /// Ignore the request and leave selection unchanged (nested navigation,
    /// a Settings sub-page, or the account row with a single profile).
    case ignore
}

enum SidebarNavigationPolicy {

    /// Resolves a requested top-level tab change.
    ///
    /// Rules (preserving the prior inline behavior exactly):
    /// - While nested navigation (a pushed detail/carousel) or a Settings
    ///   sub-page is active, tab changes are blocked.
    /// - The `.account` row never becomes the stored selection. With multiple
    ///   profiles it presents the profile switcher; otherwise it is a no-op.
    /// - Any other tab is honored.
    static func resolveSelection(
        requested: SidebarTab,
        isNested: Bool,
        isSettingsSubPage: Bool,
        hasMultipleProfiles: Bool
    ) -> SidebarSelectionOutcome {
        guard !isNested, !isSettingsSubPage else { return .ignore }

        if requested == .account {
            return hasMultipleProfiles ? .presentProfileSwitcher : .ignore
        }

        return .select(requested)
    }

    /// Returns the tab selection should fall back to when an external state
    /// change makes the current tab invalid, or `nil` to stay put.
    ///
    /// - Fresh sign-in while sitting on Settings bounces to Home, because a
    ///   library `TabSection` materializing above Settings wedges sidebar
    ///   focus on tvOS.
    /// - Disabling the Discover tab while it is selected bounces to Home so
    ///   the user is not stranded on a now-hidden tab.
    static func fallbackTab(
        currentlySelected: SidebarTab,
        freshlySignedIn: Bool,
        discoverHidden: Bool
    ) -> SidebarTab? {
        if freshlySignedIn, currentlySelected == .settings { return .home }
        if discoverHidden, currentlySelected == .discover { return .home }
        return nil
    }
}
