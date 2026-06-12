# E3-PR8 — Content Accessibility and Focus Closure

Date: 2026-06-01
Owner: Epic 3 owner
Workstream: WS-E
Branch: `codex/epic-2-pr4-canonical-hero`

## Objective

Consolidate the content-flow accessibility and focus review across the Epic 3
content surfaces (poster, preview, detail, discover, content cards) and record
the matrix status for A11Y-005..010.

## Review summary (code/policy audits; device capture pending `DEBT-E0-007`)

| Flow | Status | Basis |
| --- | --- | --- |
| A11Y-005 Poster→preview expansion | Reviewed | Reduce Motion gates entry/expand via tested `PreviewMotionPolicy` (instant, lossless); no info lost (E3-PR3). |
| A11Y-006 Preview paging | Reviewed | Paging motion gated by Reduce Motion; index change instant when reduced (E3-PR3). |
| A11Y-007 Preview exit to source row | Reviewed | Exit decision test-locked in `PreviewStateMachine`; focus returns to originating poster (E3-PR3). |
| A11Y-008 Detail primary actions | Reviewed | Metadata cascade deterministic; primary actions unchanged; VoiceOver reads stable order (E3-PR4). |
| A11Y-009 Detail seasons/episodes | Reviewed | Cascade ordering deterministic; section structure unchanged (E3-PR4). |
| A11Y-010 Watchlist/Discover actions | Reviewed | Calm accessible empty/loading surface (shared `ContentStateView`); actions unchanged (E3-PR5). |

## Focus restoration

- Home/content rows: deterministic + stale-safe via `FocusRestorationPolicy` +
  `FocusMemory` (Epic 2 E2-PR3) — covered by `FocusRestorationPolicyTests` (10),
  `FocusMemoryTests` (6).
- Preview: exit/collapse/dismiss decision covered by `PreviewStateMachineTests`
  (9); focus returns to source poster.
- New `LandscapeContentCard` exposes one combined VoiceOver element
  (`ContentCardAccessibilityTests`, 4) and is `.isButton`.

## Reduced motion

Hero (E2-PR4), preview structural transitions (E3-PR3), and content-card focus
emphasis (E3-PR7) all honour Reduce Motion. Detail/discover use no
motion-dependent information.

## Readability over artwork

Content card and CW card overlays use a bottom gradient (clear→0.55→0.85) under
title/metadata for legibility over artwork; preview/detail retain their existing
vignette/gradient treatments.

## Remaining (accepted debt)

On-device VoiceOver / focus-path / contrast capture for content flows is
required before Epic 5 and remains `DEBT-E0-007`. Live-account content states
remain `DEBT-E1-PR1-004`. No primary content flow is falsely marked complete.

## Validation

- Full suite green (see closure report E3-PR9): all Epic 3 + prior suites pass.
- `git diff --check` clean. No code change in this review slice (documentation +
  matrix consolidation).
