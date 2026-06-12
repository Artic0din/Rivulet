# E2-PR3 — Focus Model and FocusMemory Normalisation

Date: 2026-06-01

Owner: Epic 2 owner

Gates: E0-G04 (focus / VoiceOver), E0-G07 (PERF-009 focus response). Flows:
A11Y-002 (sidebar navigation), supports A11Y-001/003/004.

Scope: navigation/focus foundation. No visual redesign, no Hero default-on.

## Current focus behavior (audit)

### Ownership map

| Surface | Mechanism | Notes |
| --- | --- | --- |
| Top-level navigation | `TVSidebarView` `TabView(.sidebarAdaptable)` | System sidebar↔content focus. `SidebarTab` enum in `NavigationEnvironment`. |
| Menu / back at root | `TVSidebarView.onExitCommand { }` | Root swallows Menu (no-op) so back at the top level does not exit unexpectedly. |
| Focus containment | `installSidebarFocusGuard()` | Existing sidebar focus containment. |
| Focus-loss recovery | `focusRecoveryWatchdog()` | Every ~1.5 s: if `focusSystem.focusedItem == nil`, calls `resetFocus(in: contentNamespace)`. The current safety net for stranded focus. |
| Nested push | `resetFocus(in:)` on `nestedNavState.isNested` | Resets content focus when a detail view pushes. |
| Home rows | `InfiniteContentRow` `@FocusState focusedItemId` + `.focused(equals: focusId(for:))` + `.focusSection()` | Focus id format `"<rowID>:<itemID>"` via `focusId(for:)`. |
| Home row refresh restoration | `InfiniteContentRow.onChange(initialItemsHash)` | Saves focus, rebuilds items, restores **only if the item still exists**. |
| Preview-return restoration | `InfiniteContentRow.onChange(restorePreviewFocusTarget)` | Restores to the source item, validated against current items. |
| Watchlist hub | `WatchlistHubRow` `.defaultFocus(...)` + `.focusSection()` | First item is the default focus. |
| Loading / empty / error | `ContentStateView` (E2-PR1) | Loading: no focus target (transient). Empty/error: deterministic focus on the retry control. |
| Section focus memory (generic) | `FocusMemory` + `remembersFocus(...)` | Used by detail-style sections (Epic 3 surface). **Previously had no staleness validation.** |

### Known gaps (pre-PR)

1. `FocusMemory.recall` redirected to a remembered id **with no check that the
   id still exists** → after a refresh/removal it could strand focus on a
   vanished item, relying on the watchdog to recover (visible focus loss).
2. `InfiniteContentRow`'s refresh restoration validated staleness inline via
   `split(separator: ":", maxSplits: 1)`, which parses on the **first** colon and
   silently fails to restore for rowIDs containing ":" (e.g. `home:recommendations`).
3. The restoration rule was duplicated/inline and untested.

## Changes (after)

- New pure `FocusRestorationPolicy` + `FocusID` (`Services/Focus/FocusRestorationPolicy.swift`):
  - `FocusID.make(rowID:itemID:)` — canonical opaque identity.
  - `restoredFocusID(saved:validFocusIDs:)` — keep saved focus only if still a
    valid target, else nil (no stranded focus). Whole-string comparison, so
    colon-containing rowIDs are handled correctly.
  - `entryFocusID(remembered:orderedValidFocusIDs:)` — remembered if valid, else
    first, else nil.
- `FocusMemory` hardened (additive, non-breaking):
  - `recall(for:validIDs:)` returns the remembered id only if still valid and
    **prunes** stale entries.
  - `remembersFocus(...)` / `FocusMemoryModifier` gain an optional `validIDs`
    supplier; when provided, restoration is stale-safe. Default nil = unchanged
    behavior, so existing callers (detail sections) are not affected.
- `InfiniteContentRow` refresh restoration now uses
  `FocusRestorationPolicy.restoredFocusID` against the full set of current focus
  identities — behavior-preserving for simple rowIDs and a correctness fix for
  colon-containing rowIDs.

## Focus ownership decisions

- Home keeps the **system** sidebar↔content model (`TabView(.sidebarAdaptable)`)
  and the existing watchdog/containment. No custom focus-scope manager
  introduced (per scope guidance).
- Restoration correctness is centralised in one pure, tested policy rather than
  re-derived per view.
- Auth/not-connected, sidebar tab structure, and the watchdog are unchanged
  (the watchdog remains the last-resort recovery; the policy reduces how often
  it must fire).

## FocusMemory decisions

- Validation is **opt-in** via `validIDs` to avoid changing detail/Epic 3 focus
  behavior in this PR. Home rows get stale-safety today through the policy;
  Hero / Continue Watching / sidebar adoption of `validIDs` is the sanctioned
  pattern for E2-PR4+.

## Sidebar / content focus decisions

- Unchanged structurally. Sidebar↔content transfer is system-managed; nested
  push resets content focus; the watchdog recovers nil-focus. Documented, not
  modified — no regression.

## Loading / empty / error focus decisions

- Loading: transient, no focus target (intentional).
- Empty / error: `ContentStateView` deterministically focuses the retry control
  (E2-PR1). Confirmed still correct.
- Content: first row / first item via existing `.focused`/`.defaultFocus`;
  restoration after refresh is now stale-safe.

## Menu / back findings

- Root `onExitCommand {}` intentionally no-ops Menu at the top level (prevents
  surprise exit). Nested/detail back is handled by `NavigationStack` and
  `nestedNavState`. Not modified; not regressed.

## Accessibility findings (A11Y-002)

- Deterministic initial focus: sidebar default + row default focus preserved;
  empty/error retry focus deterministic.
- No stranded/dead-end focus on refresh now that stale restoration is rejected.
- Reduced motion: restoration uses the existing animation-disabled transaction;
  no new motion introduced.
- VoiceOver order and labels unchanged (no view structure change).
- Device VoiceOver validation on physical Apple TV remains required before Epic 5
  (tracked by `DEBT-E0-007`); not performed in this PR.

## Performance findings (PERF-009)

- Restoration is O(n) over the row's current items to build a `Set` of focus
  identities on refresh (not per focus move) — negligible. No network fetch, no
  image preload added to focus changes (scan-confirmed).
- No numeric PERF-009 median/p95 captured here; remains under `DEBT-E0-008`. The
  E2-PR1 signpost harness can time focus transitions in a later capture pass.

## Residual / unresolved

- Device VoiceOver + on-device focus validation outstanding (`DEBT-E0-007`).
- Numeric PERF-009 capture outstanding (`DEBT-E0-008`).
- UI automation for focus paths outstanding (`DEBT-E0-006`).
- Generic `FocusMemory` validation is opt-in; detail/Epic 3 sections not yet
  migrated (out of scope for E2-PR3).
