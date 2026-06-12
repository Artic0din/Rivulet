# Epic 2 Implementation Decomposition — Apple TV Home Experience

Date: 2026-06-01

Status: Planning only. No implementation authorised by this document.

Owner: Epic 2 owner.

Inputs read before writing this package:
`Docs/modernization/epic-1/epic-1-closure-report.md`,
`Docs/modernization/epic-0/gate-matrix.md`,
`Docs/modernization/epic-0/parity-scorecard.md`,
`Docs/modernization/epic-0/performance-budgets-and-baseline.md`,
`Docs/modernization/epic-0/accessibility-validation-matrix.md`,
`Docs/modernization/epic-0/observability-policy.md`,
`Docs/modernization/epic-0/debt-register.md`,
`Docs/modernization/epic-0/security-network-surface-inventory.csv`,
`Docs/modernization/epic-0/evidence-register.md`,
`Docs/superpowers/specs/2026-05-31-rivulet-modernization-roadmap-design.md`.

Epic 1 is closed with accepted debt.
Nothing in this package reopens Epic 1 or alters an Epic 1 security, token, auth, endpoint, or provider-boundary decision.

---

## 1. Objective

Make Rivulet feel premium and Apple-TV-like from first launch.

A cold launch lands in a coherent, hero-first home;
Continue Watching is prominent;
featured and discovery rows are deliberate;
loading, empty, and error states are normalised and calm;
focus is deterministic across sidebar, hero, and rows;
Siri Remote behaviour (Menu/back, click, swipe, play/pause) is predictable;
the sidebar is refined;
and Top Shelf is secure, accurate, and deep-links correctly.

Measured outcome, tied to `parity-scorecard.md`:
raise Home 3→5, Hero 2→5, Navigation 3→5, Focus 3→5, and Top Shelf 2→4,
each backed by evidence register IDs, not assertion.

This is a modernisation of an existing, sophisticated SwiftUI tvOS shell
(`TabView(.sidebarAdaptable)` in `Rivulet/Views/TVNavigation/TVSidebarView.swift`,
home in `Rivulet/Views/Media/PlexHomeView.swift`,
data via the Epic 1 `MediaProvider` boundary),
not a rewrite.

---

## 2. Scope

Epic 2 owns and may change:

- Hero-first home: promote the hero from the currently-off `@AppStorage("showHomeHero")` path to the canonical, default launch surface with stable metadata, artwork, optional logo, and resume/play action hierarchy.
- Continue Watching prominence: position, density, progress affordance, and resume behaviour.
- Featured rows and discovery rows: row strategy, ordering, titles, and density for the home surface only.
- Loading / empty / error states for home and top-level navigation surfaces: replace ad-hoc inline states in `PlexHomeView` with a shared, reusable state surface.
- Focus normalisation: a documented focus model for sidebar ↔ content, hero ↔ first row, and inter-row transitions, building on `Services/Focus/FocusMemory.swift`.
- Siri Remote behaviour: Menu/back, select, directional, and play/pause handling for home and top-level navigation, plus deterministic exit behaviour.
- Sidebar refinement: section composition, labels, selection persistence, and `FeatureFlags`-gated section visibility, on the existing `TabView(.sidebarAdaptable)` host.
- Top Shelf: secure image transport (eliminate token-bearing URLs), accurate content, correct `rivulet://` deep-link entry, and clean extension diagnostics.
- Apple TV parity for Home, Navigation, and Focus, per the parity scorecard acceptance criteria.

Surfaces Epic 2 touches as a consumer only (read-through, no boundary change):
the Epic 1 `MediaProvider` protocol,
`HomeComposer.compose(provider:)`,
`PlexWatchlistService` (read-only `isOnWatchlist`),
and the `rivulet://` deep-link entry points in `Rivulet/RivuletApp.swift`.

---

## 3. Non-goals

- No detail-page redesign, preview/poster-expansion redesign, universal details, "more ways to watch", or trailer presentation. Those are Epic 3.
- No canonical app-wide design system definition (typography/spacing/materials/motion tokens). Epic 3 owns the design language. Epic 2 stays consistent with current Glass styling and `Docs/DESIGN_GUIDE.md` and does not introduce a competing system.
- No playback engine, routing, AVKit-first policy, HDR/DV, resume-session correctness, or playback telemetry. Those are Epic 4. Epic 2 only invokes the existing play/resume entry points.
- No watchlist write flow. `DEBT-E1-PR10-001` keeps provider watchlist writes intentionally unsupported until Epic 3 supplies a metadata-bearing write contract. Epic 2 must not add `addToWatchlist`/`removeFromWatchlist` calls.
- No Live TV or Music surfacing. `FeatureFlags.liveTVEnabled` and `FeatureFlags.musicEnabled` stay `false`; Epic 2 respects them and does not re-expose those sections.
- No ATS / trust-policy changes (`DEBT-E0-001`, `NET-001`, ADR-004 — Epic 1/Epic 5 owned).
- No Sentry DSN ownership decision (`DEBT-E1-PR2-001` — Project Owner / Epic 5).
- No private Apple APIs, no Apple branding or trade dress, no claims of Apple TV-app / Up Next / universal-search integration (roadmap "Out of Scope").
- No roadmap restructuring or epic collapsing.

---

## 4. Dependencies from Epic 1

Consumed, must remain intact:

| Dependency | Source | Epic 2 use |
| --- | --- | --- |
| `MediaProvider` protocol | `Rivulet/Services/MediaProvider/MediaProvider.swift` | Home data contract: `continueWatching(limit:)`, `recentlyAdded(limit:)`, `hubs()`, `isOnWatchlist(_:)`, `libraries()` |
| `HomeComposer.compose(provider:)` → `[MediaHub]` | `Rivulet/Services/MediaProvider/HomeComposer.swift` | Stable home hub composition with primitive-synthesis fallback |
| `PlexProvider` (selected-server-token PMS adapter) | `Rivulet/Services/MediaProvider/Plex/PlexProvider.swift` | Concrete provider behind the protocol; read-only from Epic 2 |
| `PlexProviderBoundaryPolicy` | `Rivulet/Services/MediaProvider/Plex/PlexProviderBoundaryPolicy.swift` | Documents endpoint/credential ownership; Epic 2 obeys it |
| `PlexWatchlistService` (account-token read boundary) | `Rivulet/Services/Plex/PlexWatchlistService.swift` | Read-only watchlist membership for home/hero badges |
| Header-first token transport + `SensitiveDataRedactor` | `PlexNetworkManager`, redactor | All new diagnostics use the redactor; no new query-token URLs |
| Recoverable provider failure model | Discover/watchlist containment (PR 8) | Home must treat provider/hub failures as non-fatal and degrade gracefully |
| `rivulet://detail|play?ratingKey=` deep links | `Rivulet/RivuletApp.swift` (NSUserActivity continue) | Top Shelf and home re-entry target |

Data-contract assumptions (must be verified at slice start, recorded under E0-G10):

- Core PMS browse/hubs (`NET-009`, `NET-010`) are header-first and Epic 2 needs no transport change.
- `continueWatching`/`recentlyAdded`/`hubs` are sufficient to compose a hero-first home without new endpoints.
- Provider success is not required for core home; provider outage degrades to PMS-only content.

If any assumption fails, that is a candidate Epic 1 blocker — raise it against the closure report before proceeding, do not work around it.

---

## 5. Risks

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Promoting the hero re-renders/re-orders home and regresses focus restoration | Focus dead-ends, parity regression | Land focus model + `FocusMemory` keys before enabling hero by default; capture A11Y-001/003/004 before/after |
| Token-bearing Top Shelf image URLs (`NET-019`, `E0-SEC-003`) leak secrets via extension payload | Security-gate blocker (E0-G01), App Store risk | Treat Top Shelf token-safety as a gating slice; opaque/cached image handoff; no token in URL or log |
| Hero artwork/TMDB upgrade work adds launch latency | PERF-001/003 breach | Render hero from cached/primitive content first, upgrade async; signpost PERF-003 |
| Home composition reads block first paint | PERF-001/002 breach | Render shell + skeleton immediately; compose hubs async; never await provider before first useful screen |
| Inheriting token-bearing media-asset/artwork URLs (`NET-026`) into new home/hero image paths | Re-leaks contained debt | Route all artwork through existing cached/redaction-aware image path; assert no token in new URL construction |
| Touching `MediaProvider` to add home conveniences | Reopens Epic 1 boundary | Add any home-shaping logic in a view-model/composition layer above the provider, never in the boundary |
| `UI automation gap` (`DEBT-E0-006`) and `accessibility automation gap` (`DEBT-E0-007`) | No automated regression net for home | Manual UAT + accessibility evidence accepted per debt entries; record explicitly |
| Live Plex fixture unavailable (`DEBT-E1-PR1-004`) | Home behaviour under real account state unproven locally | Use representative seeded/mocked state for unit + manual UAT; flag live-UAT as inherited debt |
| Reduced-motion users lose hero/row motion cues | A11Y-001/003 failure | Honour Reduce Motion; provide non-motion states for hero rotation and focus emphasis |

---

## 6. Workstreams

- **WS-A — Home Composition & State**: render state machine (loading/empty/error/content), shared state surface, hub ordering, memoised composition. Foundation for everything else.
- **WS-B — Hero**: canonical hero (default-on), metadata/artwork/logo composition, resume/play action hierarchy, async artwork upgrade, motion + reduced-motion behaviour.
- **WS-C — Rows**: Continue Watching prominence, featured rows, discovery rows, row density and titles for home.
- **WS-D — Navigation & Sidebar**: sidebar refinement, section composition, `FeatureFlags` gating, selection persistence, deep-link re-entry into the correct section.
- **WS-E — Focus & Siri Remote**: documented focus model, `FocusMemory` keys, sidebar↔content and hero↔row transitions, Menu/back and play/pause handling, overlay enter/exit.
- **WS-F — Top Shelf (secure)**: eliminate token-bearing image URLs, opaque/cached image handoff, accurate content, `rivulet://` deep-link validation, clean extension diagnostics.
- **WS-G — Evidence & Instrumentation**: `os_signpost` for PERF-001/002/003/009/010, evidence pack scaffolding, accessibility validation records, parity-scorecard score-change submissions.

Wave alignment: this is Wave 2 (Home Experience), running alongside Epic 4 risk-reduction-only work. WS-G underpins every other workstream's gate evidence.

---

## 7. PR-sized implementation slices

Each slice is independently reviewable, non-regressive, and ships its own gate evidence (E0-G05/G10/G11). PR numbering is indicative.

- **E2-PR1 — Home render-state model + shared state surface + signposts (WS-A, WS-G)**
  Extract `PlexHomeView`'s inline loading/error/empty (`PlexHomeView.swift:134-138`) into a reusable `ContentStateView` (loading/empty/error/content), drive home from an explicit state model, add `os_signpost` for PERF-001/002/003. No visual hero change. Captures first home performance baseline (reduces `DEBT-E0-008`).

- **E2-PR2 — Top Shelf token-safety (WS-F)**
  Eliminate token-bearing image URLs in `TopShelfExtension/ContentProvider.swift` (`NET-019`, `E0-SEC-003`); move to opaque/cached image handoff via the shared app group; confirm no token in URL, log, or cache payload; validate `rivulet://` play/detail deep-links. Security-gating slice (E0-G01/G02/G08).

- **E2-PR3 — Focus model + FocusMemory normalisation (WS-E)**
  Document and implement deterministic focus for sidebar↔content and inter-row transitions on the current `TabView(.sidebarAdaptable)`; standardise `remembersFocus` keys; no dead-ends; capture A11Y-002 + PERF-009. Lands before hero default-on.

- **E2-PR4 — Canonical hero, default-on (WS-B)**
  Promote hero to default launch surface; stable metadata/artwork/logo composition; resume/play action hierarchy; render-from-cache-then-upgrade to keep PERF-003 in budget; honour Reduce Motion. Flip `showHomeHero` default to on behind a controlled rollout. Capture A11Y-001/003 + PERF-003.

- **E2-PR5 — Continue Watching prominence (WS-C)**
  Position and emphasise Continue Watching; resume affordance and progress; capture A11Y-004.

- **E2-PR6 — Featured + discovery row strategy (WS-C)**
  Deliberate home row ordering, titles, density via `HomeComposer` output; graceful empty/partial rows; no provider-write coupling.

- **E2-PR7 — Sidebar refinement + deep-link re-entry (WS-D)**
  Section composition, labels, selection persistence, `FeatureFlags` gating audit, and correct section landing for `rivulet://` + Top Shelf entry; capture A11Y-016.

- **E2-PR8 — Hero/home motion + reduced-motion + Siri Remote polish (WS-B, WS-E)**
  Hero rotation/transition motion, play/pause and Menu/back behaviour, reduced-motion fallbacks across home.

- **E2-PR9 — Settings entry consistency for home/navigation (WS-D)**
  Only home/navigation-relevant settings rows (A11Y-014 shared with Epic 5); honour the title-only settings-row + descriptor-panel rule.

- **E2-PR10 — Epic 2 evidence pack + parity score submissions + closure report (WS-G)**
  Assemble launch/home/focus captures, accessibility records, observability review notes, parity-scorecard score-change requests, and the Epic 2 closure report with accepted-debt list.

Ordering rationale: state surface and signposts first (everything depends on them); Top Shelf security blocker early; focus before hero default-on; hero before rows; navigation/sidebar and polish after the home core is stable; evidence pack last.

---

## 8. Files likely affected

App shell / navigation:
- `Rivulet/RivuletApp.swift` (deep-link landing only; not the security path)
- `Rivulet/ContentView.swift`
- `Rivulet/Views/TVNavigation/TVSidebarView.swift`
- `Rivulet/Views/TVNavigation/NavigationEnvironment.swift`
- `Rivulet/Views/Root/SidebarView.swift`

Home + hero + rows:
- `Rivulet/Views/Media/PlexHomeView.swift`
- `Rivulet/Views/Media/Hero/HeroBackdropLayer.swift`
- `Rivulet/Views/Media/Hero/HeroButtonRow.swift`
- `Rivulet/Views/Media/Hero/HeroOverlayContent.swift`
- `Rivulet/Views/Media/Hero/HeroPlaySession.swift`
- `Rivulet/Views/Media/Hero/HeroSlideContent.swift`
- `Rivulet/Views/Media/HeroBackdropSupport.swift`
- `Rivulet/Views/Media/Hubs/WatchlistHubRow.swift`
- `Rivulet/Views/Media/ContinueWatchingCard.swift`
- `Rivulet/Views/Media/MediaItemRow.swift`
- `Rivulet/Views/Media/MediaPosterCard.swift`

Shared components (new + existing):
- `Rivulet/Views/Components/` — new `ContentStateView` (loading/empty/error), reuse `CachedAsyncImage.swift`, `GlassRowStyle.swift`
- `Rivulet/Services/Focus/FocusMemory.swift`

Composition layer (consumer-side, above the Epic 1 boundary):
- `Rivulet/Services/MediaProvider/HomeComposer.swift` (read/compose only; no boundary semantics change)
- a new home view-model/composition type if extracted from `PlexHomeView`

Top Shelf:
- `TopShelfExtension/ContentProvider.swift`
- `TopShelfExtension/TopShelfCache.swift`
- `TopShelfExtension/TopShelfItem.swift`
- `Rivulet/Services/Cache/TopShelfCache.swift`
- `Rivulet/Models/Shared/TopShelfItem.swift`

Governance artifacts (updated per slice):
- `Docs/modernization/epic-0/evidence-register.md`
- `Docs/modernization/epic-0/security-network-surface-inventory.csv` (Top Shelf row `NET-019` disposition)
- `Docs/modernization/epic-0/debt-register.md`
- `Docs/modernization/epic-0/parity-scorecard.md`
- `Docs/modernization/epic-2/` (this folder; UAT + closure docs)
- `RivuletTests/` (unit + composition tests, e.g. extend `HomeComposerTests`)

---

## 9. Files that must not be changed

These encode Epic 1 security, token, auth, endpoint, and provider-boundary decisions. Epic 2 consumes them; it does not modify their semantics.

- `Rivulet/Services/MediaProvider/MediaProvider.swift` (boundary protocol — signatures fixed)
- `Rivulet/Services/MediaProvider/MediaProviderRegistry.swift`
- `Rivulet/Services/MediaProvider/Plex/PlexProvider.swift`
- `Rivulet/Services/MediaProvider/Plex/PlexProviderBoundaryPolicy.swift`
- `Rivulet/Services/Plex/PlexWatchlistService.swift`
- `Rivulet/Services/Plex/PlexWatchlistAPI.swift`
- `Rivulet/Services/Plex/PlexWatchStateRequestFactory.swift`
- `Rivulet/Services/Plex/PlexProgressReporter.swift` (Epic 4-owned playback semantics)
- `Rivulet/Services/Plex/PlexNetworkManager.swift` token-transport / auth-header paths
- `Rivulet/Services/Plex/PlexAuthManager.swift` credential lifecycle
- `Rivulet/Info.plist` ATS / trust keys (`NET-001`, ADR-004 — Epic 1/5)
- `Rivulet/RivuletApp.swift` Sentry init / DSN config (`DEBT-E1-PR2-001`)
- `Rivulet/Config/FeatureFlags.swift` (values stay `false`; do not flip Live TV/Music on)

Hard rules:
no token added to any query string;
no new undocumented host/endpoint without a `security-network-surface-inventory.csv` entry (E0-G02);
no provider watchlist write calls (`DEBT-E1-PR10-001`).

---

## 10. Apple TV parity goals

Targets and acceptance, from `parity-scorecard.md`:

| Category | Current → Target | Acceptance (must prove with evidence) |
| --- | --- | --- |
| Home | 3 → 5 | Launch lands in coherent hero-first experience; Continue Watching prominent; passes focus, performance, accessibility checks; no open blocker in category |
| Hero | 2 → 5 | Primary launch surface with stable metadata, artwork, logo, resume/play actions, deterministic focus |
| Navigation | 3 → 5 | Deterministic top-level nav with Menu/back behaviour, deep-link entry, consistent section changes |
| Focus | 3 → 5 | Sidebar, rows, hero, overlays restore and transfer focus without loss or dead ends |
| Top Shelf | 2 → 4 | Secure, accurate, deep-links correctly, no secrets in URLs or logs |
| Accessibility | 2 → 5 (inherited) | Core Epic 2 flows pass VoiceOver, focus, reduced motion, contrast, exit on device |

A category may not exceed 4 while any blocker issue remains open in it (scorecard rule 2);
score changes require evidence IDs and Project Owner acceptance (rules 1, 4, 5);
Epic 5 reviews all changes before ship.

Distinctness constraint: parity is a quality benchmark, not a clone. Rivulet keeps its own Glass visual identity; no Apple asset, name, or layout impersonation.

---

## 11. Accessibility requirements

Gate E0-G04 is operational and blocking for primary flows.
Epic 2 owns these `accessibility-validation-matrix.md` flows:

- A11Y-001 App launch to home — Focus, VoiceOver, Reduced Motion, Contrast, Exit.
- A11Y-002 Sidebar navigation — Focus, VoiceOver, Contrast, Exit.
- A11Y-003 Home hero actions — Focus, VoiceOver, Reduced Motion, Contrast, Exit.
- A11Y-004 Continue Watching row — Focus, VoiceOver, Contrast, Exit.
- A11Y-014 Settings root/subpages — Focus, VoiceOver, Contrast, Exit (shared with Epic 5).
- A11Y-016 Top Shelf deep-link entry — Focus, Exit.

Success criteria (matrix §Success Criteria):
no dead-end focus, no unexpected jumps, no focus loss on modal enter/exit, correct restoration to origin;
every actionable item has a meaningful VoiceOver label in hierarchy order;
critical info survives Reduce Motion;
primary text readable over artwork/video, overlays not blending into artwork;
Menu/back always exits predictably.

Each changed primary flow is revalidated (review rule 1).
Device validation for Home and Top Shelf is required before Epic 5 (review rule 2).
A failed primary-flow check is a blocker unless the scope is explicitly removed from the shipping plan.
Automation is not required: `DEBT-E0-007` accepts manual accessibility evidence for Epic 2 flows.

---

## 12. Performance requirements

Gate E0-G07 is operational and blocking for unexplained breaches.
Epic 2 budgets from `performance-budgets-and-baseline.md`:

| Metric | Budget | Applies to |
| --- | --- | --- |
| PERF-001 Cold launch → first useful screen | ≤ 4.0 s | Launch slice; home shell |
| PERF-002 Warm launch → first useful screen | ≤ 2.5 s | Launch slice |
| PERF-003 Home hero ready | ≤ 1.5 s after home shell | Hero slice |
| PERF-009 Focus response | ≤ 50 ms | Focus + sidebar + rows |
| PERF-010 Image cache hit | ≤ 100 ms | Hero/row cached artwork |

Capture protocol: minimum sample sizes per metric (5 launches, 20 focus moves, 20 cached image requests), median + p95 nearest-rank, `os_signpost` + unified logging, recorded with build/device/tvOS/network conditions using the document's Evidence Template.
First formal capture set must include cold + warm launch on simulator and at least one cold + warm launch on physical Apple TV.
Any performance claim in a PR cites a measured run (review rule 3).
A breach blocks merge unless explained and accepted as debt with a follow-up date.
Epic 2 producing the first home/launch captures reduces `DEBT-E0-008`.

---

## 13. Security / privacy constraints

- E0-G01 Token handling: no token in logs, crash reports, or extension-distributed URLs. The Top Shelf token-bearing image URL (`NET-019`, `E0-SEC-003`, `ContentProvider.swift:35`) must be eliminated before Top Shelf can close — opaque/cached image handoff, no token in URL or payload.
- E0-G02 Network inventory: any new host/endpoint family added to `security-network-surface-inventory.csv` before merge. Home artwork must stay on `NET-018` public CDN rules (`metadata-static.plex.tv`, `image.tmdb.org`) with no token appended, or the contained `NET-026` cached handoff. No new query-token URL construction.
- E0-G03 Privacy disclosure: any newly collected/stored/transmitted data added to the privacy matrix + manifest review. Top Shelf already has `PrivacyInfo.xcprivacy`; changes to its payload/cache require a disclosure review. `rivulet://` deep links carry rating keys/titles, no tokens (`NET-021`) — keep it that way.
- E0-G08 Observability: home, sidebar-focus, content-provider, and deep-link logs use the `ContentProvider`/`PlexHome`/`SidebarFocus`/`DeepLink` categories and the allowed-field taxonomy; forbidden fields (X-Plex-Token, token-bearing URLs, raw server URL, full extension cache payloads with sensitive URLs) never emitted. Use `SensitiveDataRedactor` for any URL-bearing diagnostic. Replace `print()` in changed Top Shelf/home surfaces with `Logger`.
- Inherited but not owned by Epic 2: ATS (`DEBT-E0-001`), Sentry DSN ownership (`DEBT-E1-PR2-001`), local-network privacy copy (`DEBT-E1-PR3-001`). Do not resolve here; do not regress.

---

## 14. Testing requirements

Gates E0-G05 (command proof) and E0-G06 (regression coverage).

- Unit/composition tests:
  extend `HomeComposerTests` for hero-candidate selection and hub ordering;
  add render-state-model tests (loading/empty/error/content);
  add focus-key/restoration logic tests where logic is unit-testable;
  add Top Shelf item-building tests proving no token in produced image URL.
- Provider failure-path tests: home composes successfully when `hubs()`/provider calls throw (graceful degradation), proving Epic 1's recoverable-failure contract holds at the home layer.
- No-regression: existing `RivuletTests` suite stays green; run the Epic 1 closure-report command set plus new Epic 2 tests on an explicit simulator UDID (the closure report notes name-based launch instability — use a UDID).
- Command proof: every "passes" claim attaches fresh `xcodebuild build` + `xcodebuild test` output with exit status and the simulator UDID, per E0-G05.
- Regression matrix: add Home/Hero/Navigation/Focus/Top Shelf entries to `regression-matrix.md`; high-risk regressions (hero default-on, focus model) need explicit coverage before merge.
- UI automation: `DEBT-E0-006` accepts manual UAT evidence in lieu of automated UI regression for these flows; record the acceptance.

---

## 15. UAT scenarios

Mapped to gate E0-G11 (UAT coverage). Capture per `accessibility-validation-matrix.md` evidence templates where accessibility overlaps.

- UAT-E2-01 Cold launch lands in hero-first home with hero artwork, title, and a working resume/play action within budget.
- UAT-E2-02 Warm relaunch restores a coherent home and prior focus context.
- UAT-E2-03 Continue Watching is prominent; resuming an item starts at the correct position.
- UAT-E2-04 Sidebar navigation between visible sections is deterministic; hidden Live TV/Music stay hidden.
- UAT-E2-05 Menu/back from home, hero, and rows behaves predictably; no dead-ends.
- UAT-E2-06 Focus moves sidebar↔content and hero↔first row and across rows without loss; returns to origin after any overlay.
- UAT-E2-07 Empty state (no Continue Watching / empty library) renders the calm empty surface, not a broken/blank screen.
- UAT-E2-08 Error state (provider/hub failure, network loss) renders a recoverable error surface; core PMS content still loads when only the provider fails.
- UAT-E2-09 Top Shelf shows accurate items; selecting one deep-links into the correct detail/play landing via `rivulet://`.
- UAT-E2-10 Top Shelf images render with no token in any URL/log/payload (security UAT).
- UAT-E2-11 Reduce Motion on: hero/row transitions remain understandable; no motion-only cues.
- UAT-E2-12 VoiceOver on: launch→home, sidebar, hero actions, Continue Watching all operable with meaningful labels.

Live-account UAT (PIN/account-state-dependent paths) is constrained by `DEBT-E1-PR1-004`; record any deferral as inherited debt.

---

## 16. Evidence requirements

Per E0-G10 every closed slice links evidence in `evidence-register.md` with an `E2-PRn-...` ID, plus dependency and known-limitation notes.

Required Epic 2 evidence pack:
- Launch capture (cold + warm) with PERF-001/002 runs (sim + device), Evidence Template filled.
- Home + hero capture with PERF-003 runs and hero composition review.
- Focus path map + PERF-009 runs for sidebar/hero/rows.
- Cached-art PERF-010 runs.
- Accessibility validation records for A11Y-001/002/003/004/014/016.
- Observability review records for changed home/sidebar/Top Shelf/deep-link sinks (field contents, redaction, sink, decision).
- Top Shelf security proof: image-URL token-safety, cache payload review, deep-link result validation, `NET-019` disposition update.
- Network-inventory review confirming no new token-bearing or undocumented endpoint.
- Parity-scorecard score-change submissions with evidence IDs for Home/Hero/Navigation/Focus/Top Shelf.
- UAT records for UAT-E2-01..12.
- Epic 2 closure report (mirroring the Epic 1 closure-report structure) with explicit accepted-debt list.

Closure evidence must be Gate-Satisfying (reviewed + mapped to gate), not merely Captured.

---

## 17. Debt expected to remain

Carried, not resolved by Epic 2 (record explicitly at closure):

- `DEBT-E0-001` ATS / local-network trust — Epic 1/Epic 5, ADR-004.
- `DEBT-E0-005` Swift 6 build truth — Epic 4/5.
- `DEBT-E0-006` UI automation gap — manual UAT accepted for Epic 2 flows; lane still absent.
- `DEBT-E0-007` Accessibility automation gap — manual accessibility evidence accepted.
- `DEBT-E1-PR1-004` Live Plex fixture coverage — live home/account UAT remains debt.
- `DEBT-E1-PR2-001` Sentry DSN ownership — Project Owner / Epic 5.
- `DEBT-E1-PR3-001` Local-network privacy copy / Bonjour — Epic 1/5.
- `DEBT-E1-PR10-001` Provider watchlist write contract — Epic 3.
- `NET-026` token-bearing PMS media-asset/artwork URLs and `NET-028` Siri/search image handoff — contained, cross-epic; Epic 2 must not extend them but does not eliminate them.

Reduced by Epic 2:
- `DEBT-E0-008` Performance baseline gap — Epic 2 produces the first home/launch capture set.
- `DEBT-E0-002` / `NET-019` token-bearing Top Shelf URL — eliminated for Top Shelf when E2-PR2 closes (reduces the Epic 2-facing portion of the token-hygiene debt).
- `DEBT-E0-004` observability — reduced for changed home/Top Shelf/deep-link sinks.

Anything newly accepted gets an owner, severity, rationale, review date, and disposition in `debt-register.md`.

---

## 18. Exit gate

From the roadmap Epic 2 contract and gate matrix, Epic 2 closes only when all are true:

1. App launch experience clearly feels Apple-TV-like (hero-first home), validated in UAT.
2. Focus behaves deterministically across sidebar, hero, rows, and overlays in UAT (no dead-ends, correct restoration).
3. Top-level navigation behaves deterministically (Menu/back, deep-link entry, section changes).
4. Loading, empty, and error states are normalised across home and top-level navigation.
5. Top Shelf is secure (no token-bearing URLs/logs/payloads), accurate, and deep-links correctly.
6. E0-G04 accessibility sign-off complete for all Epic 2 primary flows (or scope explicitly removed).
7. E0-G07 performance budgets (PERF-001/002/003/009/010) met or breaches accepted as dated debt.
8. E0-G01/G02/G03/G08 security, inventory, privacy, observability evidence reviewed and clean for changed surfaces.
9. E0-G05/G06/G11 test, regression, and UAT evidence captured with command proof.
10. E0-G10 evidence linked, dependency assumptions and known limitations recorded.
11. Parity scorecard updated with accepted score changes for Home, Hero, Navigation, Focus, Top Shelf.
12. Epic 2 closure report produced with accepted-debt list.

No blocker gate may remain open at closure (gate-acceptance checklist).

---

## 19. Recommended first PR

**E2-PR1 — Home render-state model + shared state surface + launch/home signposts.**

Why first:
- Pure consumer-side refactor above the Epic 1 boundary — touches no security/token/provider file, lowest regression risk.
- Extracts the ad-hoc inline loading/error/empty in `PlexHomeView.swift:134-138` into a reusable `ContentStateView`, the surface every later Epic 2 slice depends on (loading/empty/error states are explicit Epic 2 scope).
- Adds `os_signpost` instrumentation for PERF-001/002/003, standing up the WS-G evidence harness so every subsequent slice can prove its performance claim (E0-G07) — and produces the first home/launch baseline capture, reducing `DEBT-E0-008`.
- Establishes the home render-state model that the hero default-on slice (E2-PR4) builds on, without yet changing the visible hero (`showHomeHero` stays off this PR).

Scope guardrails:
no hero default flip, no Top Shelf change, no provider/boundary edit, no FeatureFlags change.

Evidence to attach:
`xcodebuild build` + targeted `xcodebuild test` output on an explicit simulator UDID;
PERF-001/002/003 capture set (sim, with at least one device launch noted as follow-up);
state-model unit tests;
evidence-register entries `E2-PR1-*`.

Alternative first PR, if the Project Owner prioritises the security blocker over the home foundation:
**E2-PR2 — Top Shelf token-safety** (`NET-019` / `E0-SEC-003`), since it is the highest-severity open item in Epic 2's surface and gates the Top Shelf parity score. Recommendation is E2-PR1 first (foundation + evidence harness), E2-PR2 immediately after.
