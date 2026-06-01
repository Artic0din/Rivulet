# Epic 3 Implementation Decomposition — Apple TV Content Experience

Date: 2026-06-01
Status: Planning + execution baseline (E3-PR1). Implementation authorised by the approved autonomous Epic 3 mandate.
Owner: Epic 3 owner.

Inputs read before writing this package:
`Docs/modernization/epic-2/epic-2-closure-report.md`,
`Docs/modernization/epic-2/epic-2-decomposition.md`,
`Docs/modernization/epic-0/{gate-matrix,parity-scorecard,accessibility-validation-matrix,performance-budgets-and-baseline,observability-policy,debt-register,evidence-register,security-network-surface-inventory.csv}.md`,
`Docs/modernization/epic-1/epic-1-closure-report.md`,
and a direct code audit of the content surfaces (see §4).

Epic 1 and Epic 2 are closed with accepted debt. Nothing in this package reopens
an Epic 1 security/token/auth/endpoint/provider-boundary decision or an Epic 2
home/navigation decision, nor does it touch playback (Epic 4).

---

## 1. Objective

Make content browsing, expansion, and selection feel first-party quality: a
single canonical content design language; smooth, deterministic poster→preview
transitions with reliable focus restoration; a coherent detail-page hierarchy
and metadata cascade; consistent watchlist / discover / universal-details /
more-ways-to-watch presentation with calm failure states; and accessible,
reduced-motion-safe content flows.

Measured outcome, tied to `parity-scorecard.md`: raise Preview 4→5, Detail 3→5,
Visual Language 3→5, and contribute Accessibility evidence — each backed by
evidence-register IDs, not assertion. Scores remain capped at 4 while any
device/numeric blocker is open (Score Change Rule 2).

This is a refinement of an existing, sophisticated SwiftUI tvOS content layer
(`MediaDetailView`, `PreviewOverlayHost`, `MediaPosterCard`, `DiscoverView`,
`WatchlistHubRow`), not a rewrite.

---

## 2. Scope

Epic 3 owns and may change:

- Canonical content design system: a semantic token layer (color/opacity,
  material, depth/shadow, motion/spring, metadata typography ramp) consolidating
  values currently duplicated inline across content surfaces, layered on the
  existing `ScaledDimensions`.
- Poster→preview transition and metadata reveal: timing, determinism, and focus
  restoration on the existing `PreviewOverlayHost`/`PreviewContainerViewController`
  UIKit-modal carousel.
- Detail-page hierarchy: title/logo/metadata cascade ordering and density;
  seasons/episodes/trailers/related presentation consistency on `MediaDetailView`.
- Watchlist / Discover / universal-details / more-ways-to-watch presentation and
  failure/empty/loading states (consumer-side, on top of the Epic 1 read
  boundaries).
- Content-flow focus restoration and VoiceOver/reduced-motion behavior for
  poster, preview, and detail.
- Apple TV parity for Preview, Detail, and Visual Language.

Surfaces Epic 3 touches as a consumer only (no boundary change):
the Epic 1 `MediaProvider` protocol, `PlexWatchlistService` (read-only
`isOnWatchlist`), `PlexDataStore` reads, TMDB discover reads, and the existing
play/resume entry points (invoked, not modified).

---

## 3. Non-goals

- No playback engine, routing, AVKit/AVPlayerViewController policy, RPlayer,
  FFmpeg/remux, Dolby Vision, HDR, subtitle/audio routing, or timeline-reporting
  change. Those are Epic 4. Epic 3 only invokes existing play/resume entry points.
- No Epic 1 boundary change: provider architecture, auth/token transport, server
  selection, Plex Home identity, watch-state ownership, endpoint classification.
- No watchlist mutation-contract change. `DEBT-E1-PR10-001` is only closed if a
  metadata-bearing write contract is *legitimately* delivered within scope and
  without touching the Epic 1 boundary; otherwise it is carried, and Epic 3 adds
  no `addToWatchlist`/`removeFromWatchlist` calls.
- No app rename (Arc deferred): no display-name, bundle, product, target, repo,
  or user-facing brand string change.
- No project-setting change: deployment target, Swift version, signing,
  entitlements, project file structure, package dependencies.
- No Apple branding/asset/icon/layout cloning or private API.
- No broad visual rewrite outside content surfaces; no Home/Sidebar/Settings
  redesign (Epic 2 owned those and they stay as-is).
- No `FeatureFlags` flip (Live TV / Music stay hidden).

---

## 4. Current-state audit

| Surface | File(s) | Finding |
| --- | --- | --- |
| Dimensional system | `Services/UIScale.swift` (`ScaledDimensions`) | Real, used widely: poster sizes, type sizes, spacing, radii, `uiScale` env. **No semantic token layer** for color/opacity/material/depth/motion — those are inline literals. |
| Glass styling | `Views/Components/GlassRowStyle.swift` | 4 button styles + glass background with **duplicated** `.white.opacity(0.18/0.12/0.2)`, `scaleEffect(1.02/1.08/1.1)`, `spring(response:0.25/0.3)` values. |
| Poster card | `Views/Media/MediaPosterCard.swift` (402) | Mature; inline focus scale/opacity/metadata layout. |
| Preview | `Views/Media/PreviewOverlayHost.swift` (905), `PreviewContainerViewController.swift` (134), `PreviewContext.swift` (161) | UIKit-modal carousel shared by Home/Library/Discover; transition + focus-restore logic inline, untested. |
| Detail | `Views/Media/MediaDetailView.swift` (3748) | Canonical detail; **does not** use `RenderState`/`ContentStateView`; metadata/seasons/episodes/related composition inline; very large. |
| Discover | `Views/Discover/DiscoverView.swift` (407) + `DiscoverViewModel` | Hero + curated sections; **no** `RenderState`/`ContentStateView`; ad-hoc loading/empty/error. |
| Watchlist | `Views/Media/Hubs/WatchlistHubRow.swift` (289) | Read-only membership; transient write-error toast wired. |
| Focus | `FocusRestorationPolicy` + `FocusMemory` (Epic 2/3 PR3) | Adopted in `PlexHomeView`, `MediaDetailView`; not yet uniformly in preview/discover. |
| State surface | `Views/Components/{RenderState,ContentStateView}.swift` (E2-PR1) | Reusable, accessible; adopted on Home only. Detail/Discover can reuse it. |

Gap summary: no canonical semantic token layer; preview transition/focus logic
is untested; detail/discover lack the shared state surface; metadata cascade
ordering is implicit. None of these require touching Epic 1 or playback.

---

## 5. Governing constraints

- Distinctness: Apple TV quality as benchmark, no Apple asset/name/layout/trade-
  dress cloning or private API (roadmap "Out of Scope").
- Epic 1 boundary files (must not change): `MediaProvider.swift`,
  `MediaProviderRegistry.swift`, `Plex/PlexProvider.swift`,
  `PlexProviderBoundaryPolicy.swift`, `PlexWatchlistService.swift`,
  `PlexWatchlistAPI.swift`, `PlexWatchStateRequestFactory.swift`,
  `PlexProgressReporter.swift`, `PlexNetworkManager` token paths,
  `PlexAuthManager` credential lifecycle, `Info.plist` ATS, Sentry DSN,
  `FeatureFlags.swift`.
- Playback files (Epic 4, must not change): `Services/Plex/Playback/**`,
  `Views/Player/**`, `ContentRouter`, `NativePlayerViewController`.
- Project settings unchanged (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`,
  deployment target, Swift version, signing) — pure value types added by Epic 3
  use `nonisolated` to stay warning-clean, as established in E2-PR6.
- Observability: changed content diagnostics use `SensitiveDataRedactor`; no
  token/credential/URL in logs, UI payloads, or deep links.

---

## 6. Workstreams

- **WS-A — Content Design System**: semantic token layer (color/opacity,
  material, depth, motion, metadata type ramp) over `ScaledDimensions`;
  refactor `GlassRowStyle` constants to tokens; canonical design doc.
- **WS-B — Preview & Poster**: poster→preview transition timing/determinism,
  metadata reveal, focus restoration; extract a pure transition/focus policy.
- **WS-C — Detail**: metadata cascade ordering policy; seasons/episodes/trailers/
  related presentation consistency; adopt `ContentStateView` for detail load/error.
- **WS-D — Watchlist/Discover/Universal/More-Ways**: presentation + failure/empty
  states via the shared state surface; watchlist-write contract assessment.
- **WS-E — Content Accessibility & Focus**: VoiceOver/focus/reduced-motion review
  and labels across poster/preview/detail; accessibility-matrix updates.
- **WS-F — Evidence & Closure**: parity submissions, evidence pack, closure report.

---

## 7. Proposed PR slices

Each slice is independently reviewable, reversible, build-green, and ships its
own gate evidence (E0-G05/G10/G11).

- **E3-PR1 — Decomposition + content baseline** (WS-F): this document + audit;
  no app behavior change.
- **E3-PR2 — Canonical content design system** (WS-A): `ContentDesignTokens`
  (semantic color/opacity/material/depth/motion + metadata type ramp), refactor
  `GlassRowStyle` constants to tokens (behavior-identical), tracked design doc.
  Pure token tests.
- **E3-PR3 — Preview expansion + poster transition polish** (WS-B): extract a
  pure `PreviewTransitionPolicy` (reveal timing, reduced-motion gating, focus-
  restore target selection) and route the existing overlay through it; no
  playback change. Pure policy tests.
- **E3-PR4 — Detail hierarchy + metadata cascade** (WS-C): pure
  `DetailMetadataCascade` (deterministic ordered metadata lines + section order)
  consumed by `MediaDetailView`; adopt `ContentStateView` for detail load/error.
  Pure cascade tests.
- **E3-PR5 — Watchlist / Discover / universal / more-ways presentation** (WS-D):
  shared state surface + calm failure states on Discover and watchlist surfaces;
  `DEBT-E1-PR10-001` reassessed (closed only if legitimately resolved).
- **E3-PR6 — Content accessibility & focus closure** (WS-E): VoiceOver labels,
  focus order/restoration, reduced-motion review across poster/preview/detail;
  accessibility-matrix updates; pure focus-policy tests where extractable.
- **E3-PR7 — Epic 3 closure evidence** (WS-F): closure report, parity
  submissions, debt review, open-limitation register, recommendation.

Slices may be re-scoped if code reality requires, but each stays reviewable and
reversible.

---

## 8. Acceptance criteria (exit gate)

Epic 3 closes only when all are true:
1. One canonical content design language exists and is applied consistently
   across the content surfaces (tokens, not scattered literals).
2. Poster→preview transition is smooth and deterministic; focus restores to the
   originating poster on exit (no dead-ends).
3. Detail-page hierarchy presents a coherent, deterministic metadata cascade and
   consistent seasons/episodes/trailers/related presentation; load/error states
   normalised.
4. Watchlist/Discover/universal/more-ways presentation has calm, recoverable
   failure/empty states; no provider-boundary change; no secret leakage.
5. Content-flow accessibility (VoiceOver, focus, reduced motion, readability,
   Menu/back) audited; device capture may remain dated debt.
6. Tests/regression/UAT evidence captured with command proof; full suite green.
7. Parity scorecard updated (proposed) for Preview/Detail/Visual Language.
8. Evidence linked; dependencies and limitations recorded.
9. Closure report produced with accepted-debt list and recommendation.
No blocker gate may remain open at closure.

---

## 9. Risks

| Risk | Impact | Mitigation |
| --- | --- | --- |
| `MediaDetailView` is 3748 lines; broad edits risk regressions | High | Extract pure policies; wire consumer-side; no structural rewrite |
| Preview transition is UIKit-modal + timing-sensitive | Focus loss / jank | Pure policy for timing/focus-target only; preserve existing animation host; capture A11Y-005/006/007 |
| Token refactor changes visuals subtly | Visual regression | Tokens seeded to current literal values; behavior-identical; diff-reviewed |
| No live Plex/TMDB fixture locally (`DEBT-E1-PR1-004`) | Real-data presentation unproven | Pure-logic tests + manual UAT; record as debt |
| Touching watchlist writes reopens Epic 1 | Boundary breach | No mutation calls; `DEBT-E1-PR10-001` only closed if contract delivered without boundary change |
| Device a11y/perf capture unavailable (`DEBT-E0-007/008`) | Parity capped at 4 | Accept dated debt; do not falsely close |

---

## 10. Evidence requirements

Per E0-G10, every closed slice links `E3-PRn-*` evidence in
`evidence-register.md` with dependency and known-limitation notes: design-token
review, preview transition/focus capture, detail cascade review, presentation
failure-state review, accessibility records (A11Y-005..010), observability review
for changed content sinks, parity submissions, and the closure report. Evidence
must be Gate-Satisfying, not merely Captured.

---

## 11. Accessibility requirements

Epic 3 owns matrix flows A11Y-005 (poster→preview expansion), A11Y-006 (preview
paging), A11Y-007 (preview exit to source row), A11Y-008 (detail primary
actions), A11Y-009 (detail seasons/episodes), A11Y-010 (watchlist/discover
actions). Success criteria per matrix §Success Criteria: no dead-end focus,
correct restoration to origin after preview/sheet/overlay dismissal, meaningful
VoiceOver labels in hierarchy order, critical info survives Reduce Motion,
readable text over artwork. Device validation may remain `DEBT-E0-007` debt but
is not falsely closed.

---

## 12. Performance requirements

Budgets from `performance-budgets-and-baseline.md`: PERF-009 focus response
≤50 ms, PERF-010 image cache hit ≤100 ms, and preview "time to first motion".
No network fetch or heavy image preload on focus movement. Reuse the existing
cached-image path and `HomePerformanceTracer` where relevant. Numeric capture
may remain `DEBT-E0-008` debt.

---

## 13. Security / privacy requirements

E0-G01/G02/G03/G08: no token in logs/UI payloads/deep links; artwork stays on
the existing cached/redaction-aware path with no token appended; any changed
content diagnostic uses `SensitiveDataRedactor`; no new network host/endpoint
without a `security-network-surface-inventory.csv` entry. Deep links carry
rating keys/titles, never tokens.

---

## 14. Regression matrix (Epic 3 entries)

| Area | Risk | Coverage before merge |
| --- | --- | --- |
| Design tokens | Visual drift from literal→token | Token unit tests assert seeded values == prior literals; build diff review |
| Preview transition | Focus loss / non-deterministic reveal | `PreviewTransitionPolicy` unit tests; manual UAT A11Y-005/006/007 |
| Detail cascade | Wrong/duplicated metadata order | `DetailMetadataCascade` unit tests (movie/episode/show, missing fields) |
| Detail states | Broken load/error surface | `ContentStateView` reuse; existing `RenderStateResolverTests` |
| Discover/watchlist states | Blank/leaky failure states | Presentation tests + redaction reuse (`HomeErrorPresentation`-style) |
| Existing suites | No regression | Full `RivuletTests` green on UDID each slice |

---

## 15. Closure checklist

- [ ] All §8 acceptance criteria met or explicitly debt-accepted.
- [ ] `E3-PR1..7` committed, each independently reviewable/reversible.
- [ ] Full suite green with command proof on the working UDID.
- [ ] Parity submissions for Preview/Detail/Visual Language (pending Owner).
- [ ] Accessibility A11Y-005..010 audited; device capture noted as debt.
- [ ] Debt register updated; `DEBT-E1-PR10-001` resolved or carried with rationale.
- [ ] No Epic 1 / playback / project-setting / rename change in any commit.
- [ ] Epic 3 closure report produced with recommendation.
