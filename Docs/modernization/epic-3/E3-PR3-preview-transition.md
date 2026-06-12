# E3-PR3 — Preview Expansion and Poster Transition Polish

Date: 2026-06-01
Owner: Epic 3 owner
Workstream: WS-B (Preview & Poster)
Branch: `codex/epic-2-pr4-canonical-hero`

## Objective

Make the poster→preview transition deterministic and Reduce-Motion-safe while
preserving focus restoration. No playback change.

## Audit findings (before)

The preview flow (`PreviewOverlayHost`, `PreviewContainerViewController`,
`PreviewContext`) is mature and shared across Home/Library/Discover:

- A pure `PreviewStateMachine` (in `PreviewContext`) already governs phase,
  motion-lock, and the Back/exit decision (`exitAction()` → collapse-to-carousel
  vs dismiss-overlay) — the determinism contract. **But it had no tests.**
- Focus restoration on dismiss already returns focus to the originating poster
  via `onDismiss(request.sourceTarget)` — correct, Apple-TV-like (the row did not
  scroll). **Preserved unchanged.**
- The structural transitions (entry morph, paging slide, expand, collapse) use
  explicit `Animation` constants but had **no Reduce Motion handling** — an A11Y
  gap (matrix A11Y-005/006 require reduced motion).

## Change (after)

1. Locked the existing determinism contract with `PreviewStateMachineTests` (9)
   and `PreviewLoadGate` coverage: entry→carousel, expand flow, exit decisions
   (carousel→dismiss, expanded/details→collapse), out-of-order guards, motion-
   lock invariants, stale-token invalidation.
2. Added a pure, tested `PreviewMotionPolicy` and wired it at the four
   structural motion sites (entry morph, paging, expand, collapse). With Reduce
   Motion enabled the transition is applied **without animation** — the state
   still changes instantly, so the destination/info is never lost (matrix rule
   "critical info survives Reduce Motion"). Full motion is unchanged otherwise.

Focus restoration, the transition timings, and the carousel/expand behavior are
otherwise unchanged. No playback, provider, or boundary change.

## Scope guardrails honored

- No change to `onDismiss`/focus-restore semantics (preserved).
- No playback / `MediaDetailView` data-cascade change.
- Reduce Motion gates structural motion only; opacity fades (not motion) are
  left as-is. A full reduced-motion sweep of every secondary animation +
  on-device validation is E3-PR6 / `DEBT-E0-007`.

## Accessibility (A11Y-005/006/007)

- A11Y-005 (poster→preview expansion) / A11Y-006 (paging): structural motion now
  honours Reduce Motion (instant, lossless).
- A11Y-007 (exit to source row): exit decision is now test-locked
  (collapse-vs-dismiss) and focus returns to the originating poster.
- On-device VoiceOver/focus capture remains `DEBT-E0-007`.

## Validation

- `xcodebuild build` exit 0, 0 errors, no new isolation warnings.
- `PreviewStateMachineTests` (9) + `PreviewMotionPolicyTests` (3) +
  `FocusRestorationPolicyTests` (10) pass → ** TEST SUCCEEDED **.
- `git diff --check` clean.
