# E2-PR1 — Accessibility Review (Foundation)

Date: 2026-06-01

Owner: Epic 2 owner

Gate: E0-G04 (Accessibility — Focus and VoiceOver).

Scope note: E2-PR1 is an enabling PR with **no visual redesign**. It introduces a
shared state surface (`ContentStateView`) that replaces three inline Home state
views with byte-equivalent presentations. This review covers the accessibility
characteristics of that shared surface. Full device VoiceOver/focus capture for
the primary Home flows (A11Y-001/002/003/004) is performed in the later Epic 2
PRs that actually change those flows; that device validation remains required
before Epic 5 and is not claimed complete here.

## Surface reviewed

`Rivulet/Views/Components/ContentStateView.swift` — loading / empty / error
presentations and the shared retry control.

## Findings

| Mode | Treatment | Result |
| --- | --- | --- |
| Focus path | Error/empty states expose a single focusable retry control; `@FocusState` sets deterministic initial focus on appear. Loading state has no focus target (transient). Content state delegates to existing Home content (unchanged). | Pass (foundation) |
| VoiceOver | Loading is a combined static element labelled "Loading". Message states combine icon + title + message into a contained group; the retry button is a separate operable element with an explicit label (action title) and a hint ("<title>. Activates to retry."). | Pass (foundation) |
| Reduced Motion | Presentations are static; no custom transitions or motion are introduced, so there is nothing to suppress under Reduce Motion. `@Environment(\.accessibilityReduceMotion)` is available for later motion work. | Pass |
| Contrast / Readability | Visuals are byte-equivalent to the prior Home state views (`.secondary` foreground, system title fonts). No regression vs current baseline. | Pass (no change) |
| Exit behavior | State surface does not capture Menu/back; existing `NavigationStack` / sidebar exit behavior is unchanged. | Pass (no change) |

## Deterministic focus decision

Error/empty states set initial focus to the retry control via `@FocusState`
rather than relying on implicit tvOS first-focusable resolution. On tvOS the
retry button is currently the only focusable element in those states, so this is
belt-and-suspenders today; it becomes load-bearing once these states gain
additional controls in later PRs.

## Not covered here (carried to later Epic 2 PRs)

- Device VoiceOver capture for A11Y-001 (launch→home), A11Y-002 (sidebar),
  A11Y-003 (hero actions), A11Y-004 (Continue Watching). These flows are not
  changed by E2-PR1.
- `recommendationsSection` and library/discover empty/error states still use
  their own inline presentations.
