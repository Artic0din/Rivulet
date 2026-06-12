# E2-PR6 — Sidebar and Top-Level Navigation Refinement

Date: 2026-06-01
Owner: Epic 2 owner
Workstream: WS-D (Navigation & Sidebar), WS-E (Focus & Siri Remote)
Branch: `codex/epic-2-pr4-canonical-hero`

## Objective

Make top-level navigation deterministic, native, and Apple-TV-quality without
introducing a custom navigation engine or a visual sidebar redesign.

## Audit findings (before)

The sidebar (`TVSidebarView`, `TabView(.sidebarAdaptable)`) is already mature:

- Sidebar focus containment is enforced by a `shouldUpdateFocus(in:)` swizzle
  that blocks downward focus escape (`installSidebarFocusGuard`,
  `overrideSidebarFocusBehavior`) — the native, Apple-TV-app-like behavior.
- A `focusRecoveryWatchdog` restores focus to the content namespace when the
  focus system ends up with `focusedItem == nil` after overlays.
- `.onExitCommand { }` on the root absorbs Menu at the top level; nested
  surfaces handle their own exit.
- Tab-bar visibility is driven by `nestedNavState` so Menu/back and section
  changes stay consistent while detail/carousel/settings sub-pages are active.

The gap was **not** behavior — it was that the *navigation decisions* were
expressed as inline, untestable guards spread across the `TabView` selection
binding and three `onChange` handlers:

- block tab changes while `isNested` / `isSettingsSubPage`;
- never store `.account`, instead present the profile switcher when multiple
  profiles exist;
- bounce Settings → Home on fresh sign-in (avoids a tvOS focus wedge when a
  library `TabSection` materializes above Settings);
- bounce Discover → Home when the Discover tab is disabled while selected.

These rules had no unit coverage and were easy to regress.

## Change (after)

Extracted the pure decisions into `SidebarNavigationPolicy`
(`Rivulet/Services/Navigation/SidebarNavigationPolicy.swift`):

- `resolveSelection(requested:isNested:isSettingsSubPage:hasMultipleProfiles:)
  -> SidebarSelectionOutcome` (`.select`, `.presentProfileSwitcher`, `.ignore`).
- `fallbackTab(currentlySelected:freshlySignedIn:discoverHidden:) -> SidebarTab?`.

`TVSidebarView` now delegates: the selection binding applies the resolved
outcome, and the two redirect `onChange` handlers call `fallbackTab`. Behavior
is preserved exactly; it is now deterministic and unit-tested.

`SidebarTab` and `SidebarSelectionOutcome` are marked `nonisolated` (pure value
data) so their `Equatable`/`Hashable` conformances are usable from any context.
This eliminates the main-actor-isolated-conformance warning that the project's
`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` setting would otherwise attach to
the new comparable result type — a correctness improvement, not a workaround.

No custom navigation engine, no visual sidebar redesign, no project-setting
change, no Epic 1 boundary touched.

## Scope guardrails honored

- No change to the sidebar focus-guard swizzle or the recovery watchdog
  (working, native behavior — left intact).
- No deep-link/section-landing behavior change (deep links still present a
  `fullScreenCover` detail or the player; they do not mutate `selectedTab`).
- No `FeatureFlags` flip (Live TV / Music stay hidden, gating logic unchanged).
- No project settings, deployment target, Swift version, or PR #1 CI change.

## Accessibility (A11Y-002)

Top-level navigation determinism is now provable: tab changes during nested
navigation are blocked, the account row never strands selection, and disabled/
invalid tabs fall back to Home rather than leaving the user on a hidden tab.
VoiceOver labels and focus order on the sidebar are unchanged. On-device
VoiceOver/focus capture remains required before Epic 5 (`DEBT-E0-007`).

## Validation

- `xcodebuild build` exit 0; new code emits no isolation warnings.
- `SidebarNavigationPolicyTests` (12) pass; `HomeRowOrderingPolicyTests` and
  `FocusRestorationPolicyTests` still pass (no regression).
- `git diff --check` clean.
