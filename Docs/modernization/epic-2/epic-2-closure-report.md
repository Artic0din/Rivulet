# Epic 2 — Apple TV Home Experience — Closure Report

Date: 2026-06-01
Owner: Epic 2 owner
Branch: `codex/epic-2-pr4-canonical-hero`
Status: **Complete with accepted debt** (recommend close; see §13)

This report mirrors the Epic 1 closure-report structure and satisfies exit-gate
item 12 (`epic-2-decomposition.md` §18) and evidence requirement E0-G10.

---

## 1. Objective status

Epic 2 goal: make Rivulet feel premium and Apple-TV-like from first launch,
without copying Apple branding, trade dress, private APIs, or unsupported
integrations.

| Exit-gate criterion (§18) | Status | Basis |
| --- | --- | --- |
| 1. Launch feels Apple-TV-like (hero-first home) | Met (code/UAT pending device) | E2-PR4 canonical hero default-on; `HeroSelectionPolicy` |
| 2. Deterministic focus (sidebar/hero/rows/overlays) | Met for Home/sidebar/hero (code) | E2-PR3 `FocusRestorationPolicy`, E2-PR4 default-focus, E2-PR6 nav policy |
| 3. Deterministic top-level navigation | Met (code) | E2-PR6 `SidebarNavigationPolicy`; native swizzle/watchdog intact |
| 4. Normalised loading/empty/error states | Met | E2-PR1 `ContentStateView`; E2-PR7 sanitized error copy |
| 5. Top Shelf secure + accurate + deep-links | Met (security); device capture pending | E2-PR2 token-free local-file handoff |
| 6. Accessibility sign-off for Epic 2 flows | **Partial** — code/policy audits done; on-device capture deferred | `DEBT-E0-007` |
| 7. Performance budgets met or accepted | **Partial** — harness in place; numeric capture deferred | `DEBT-E0-008` |
| 8. Security/inventory/privacy/observability clean | Met for changed surfaces | E2-PR2, E2-PR7; no new endpoints |
| 9. Test/regression/UAT evidence with command proof | Met (unit/regression); UAT manual pending | 461 tests pass; `DEBT-E0-006` |
| 10. Evidence linked, assumptions/limitations recorded | Met | evidence-register `E2-PR1..7-*` |
| 11. Parity scorecard updated | Met (proposed; awaiting Project Owner) | scorecard proposed-changes table |
| 12. Closure report with accepted-debt list | Met | this document |

All software-buildable, testable criteria are met. The two partial items (6, 7)
are not Epic 2 software gaps — they are the inherited device-capture
(`DEBT-E0-007`) and numeric-performance (`DEBT-E0-008`) limitations the
decomposition explicitly accepted (§17), and they cap parity at 4 rather than
blocking closure.

---

## 2. PR slices completed

| Slice | Commit | Summary |
| --- | --- | --- |
| E2-PR1 | `638efd9` | Home render-state model (`RenderState`/`RenderStateResolver`/`ContentStateView`) + `HomePerformanceTracer` signpost harness |
| E2-PR2 | `d508921` | Top Shelf token-safe local-file image handoff (`NET-019`/`E0-SEC-003` eliminated) |
| E2-PR3 | `9aa37cf` | Deterministic stale-safe focus restoration (`FocusRestorationPolicy` + hardened `FocusMemory`) |
| E2-PR4 | `2211213` | Canonical hero-first home, default-on, deterministic `HeroSelectionPolicy`, reduced-motion |
| E2-PR5 | `69004a5` | Continue Watching prominence (`HomeRowOrderingPolicy`) + combined VoiceOver label |
| E2-PR6 | `b5dd93c` | Deterministic top-level navigation (`SidebarNavigationPolicy`); `nonisolated` nav types |
| E2-PR7 | `86b776c` | Sanitized Home error copy (`HomeErrorPresentation`) — no technical/secret strings on screen |

Each slice is independently reviewable, reversible, build-green, and ships its
own evidence IDs. None modifies an Epic 1 boundary, project setting, deployment
target, Swift version, the app name, or PR #1 CI/review setup.

> Slice numbering note: the original decomposition tabled E2-PR6 as
> "featured + discovery rows" and E2-PR7 as sidebar/nav. The approved
> mid-epic direction (2026-06-01) re-mapped the remaining work to
> E2-PR6 = sidebar/navigation, E2-PR7 = state polish, E2-PR8 = closure, and
> dropped a standalone featured/discovery-row slice (home row strategy is
> covered by E2-PR5 ordering + existing `HomeComposer`/library hubs). This
> report uses the approved mapping.

---

## 3. Files changed by slice

- **E2-PR1**: `ContentView.swift`, `Services/Performance/HomePerformanceTracer.swift`, `Views/Components/{RenderState,ContentStateView}.swift`, `Views/Media/PlexHomeView.swift`, tests `{RenderStateResolver,HomePerformanceTracer}Tests`.
- **E2-PR2**: `Models/Shared/TopShelfItem.swift`, `Services/Cache/{TopShelfCache,TopShelfPayloadBuilder}.swift`, `Services/Plex/PlexDataStore.swift`, `TopShelfExtension/{ContentProvider,TopShelfCache,TopShelfItem}.swift`, test `TopShelfPayloadSafetyTests`, inventory `security-network-surface-inventory.csv`.
- **E2-PR3**: `Services/Focus/{FocusMemory,FocusRestorationPolicy}.swift`, `Views/Media/PlexHomeView.swift`, tests `{FocusMemory,FocusRestorationPolicy}Tests`.
- **E2-PR4**: `Services/MediaProvider/HeroSelectionPolicy.swift`, `Views/Media/Hero/HeroOverlayContent.swift`, `Views/Media/PlexHomeView.swift`, test `HeroSelectionPolicyTests`, parity scorecard.
- **E2-PR5**: `Services/MediaProvider/HomeRowOrderingPolicy.swift`, `Views/Media/{ContinueWatchingCard,PlexHomeView}.swift`, test `HomeRowOrderingPolicyTests`.
- **E2-PR6**: `Services/Navigation/SidebarNavigationPolicy.swift`, `Views/TVNavigation/{NavigationEnvironment,TVSidebarView}.swift`, test `SidebarNavigationPolicyTests`.
- **E2-PR7**: `Views/Media/HomeErrorPresentation.swift`, `Views/Media/PlexHomeView.swift`, test `HomeErrorPresentationTests`.

Governance artifacts updated across slices: `evidence-register.md`,
`debt-register.md`, `security-network-surface-inventory.csv`,
`accessibility-validation-matrix.md`, `parity-scorecard.md`, `CHANGELOG.md`,
and per-slice `Docs/modernization/epic-2/E2-PRn-*.md`.

---

## 4. Apple TV parity score changes (proposed, pending Project Owner)

| Category | Was | Proposed | Slice | Capped reason |
| --- | --- | --- | --- | --- |
| Home | 3 | 4 | E2-PR4 (+PR1/3/7) | Device A11Y-001 + numeric launch perf outstanding |
| Hero | 2 | 4 | E2-PR4 | Device A11Y-003 + reduced-motion + PERF-003 numeric |
| Navigation | 3 | 4 | E2-PR6 | E2E Siri Remote + deep-link re-entry + device focus |
| Focus | 3 | 4 | E2-PR3 (+PR4) | Preview/detail/player focus (Epic 3/4) + device + PERF-009 |
| Top Shelf | 2 | 4 | E2-PR2 | On-device render + deep-link landing capture |

All five Epic 2 categories reach the **4** ceiling. Reaching **5** requires
on-device capture and numeric performance runs — explicitly out of local scope
per `DEBT-E0-007`/`DEBT-E0-008`, and reviewed by Epic 5 before ship.
Scores are proposals; Score Change Rule 4 requires Project Owner acceptance and
the scorecard's printed `Current Score` cells remain unchanged until then.

---

## 5. Accessibility status

Code/policy audits complete for the Epic 2 primary flows:

- A11Y-001 (launch→home): hero-first, deterministic focus, sanitized state copy.
- A11Y-002 (sidebar nav): deterministic selection/fallback, native focus guard.
- A11Y-003 (hero actions): VoiceOver labels, default focus on Play, reduced-motion gating.
- A11Y-004 (Continue Watching row): combined VoiceOver element, pinned prominence.
- A11Y-016 (Top Shelf deep-link): token-free entry (E2-PR2).

**On-device VoiceOver/focus/contrast capture is deferred (`DEBT-E0-007`)** and is
required before Epic 5 ship per the matrix review rules. Not falsely marked
complete.

---

## 6. Performance status

`HomePerformanceTracer` (`os_signpost`, E2-PR1) instruments launch→home,
render-state transitions, and hero preparation against PERF-001/002/003.
No slice adds blocking network or image work on focus movement (PERF-009),
and all new selection/ordering/sanitization logic is pure in-memory.

**Numeric capture sets (5 launches, 20 focus moves, device + simulator) are
deferred (`DEBT-E0-008`).** The harness exists; the measured runs are an Epic 5
pre-ship task. No budget is claimed as numerically proven.

---

## 7. Security / privacy status

- E2-PR2 eliminated the token-bearing Top Shelf image URL (`NET-019`,
  `E0-SEC-003`) — opaque local-file handoff, no token in URL/log/payload.
- E2-PR7 closed a UI error-copy leak vector — no token/credential/URL can reach
  on-screen Home copy (`SensitiveDataRedactor` + technical-shape fallback).
- No new network host/endpoint added; artwork stays on existing CDN/contained
  paths. No `FeatureFlags` flip; Live TV/Music remain hidden.
- No change to token transport, auth headers, ATS, or Sentry DSN ownership.

Clean for all changed surfaces (E0-G01/G02/G03/G08).

---

## 8. Testing / build status

- `xcodebuild build` (UDID `F8288707-280A-4C5F-94AA-24B706E66909`): exit 0,
  0 errors. Pre-existing `DEBT-E0-005` warnings only; new code adds no isolation
  warnings.
- Full suite: **461 tests passed, 0 failed.**
- Epic 2 pure-policy coverage added this epic: `RenderStateResolver` (12),
  `HomePerformanceTracer` (4), `TopShelfPayloadSafety` (10), `FocusMemory` (6),
  `FocusRestorationPolicy` (10), `HeroSelectionPolicy` (11),
  `HomeRowOrderingPolicy` (5), `SidebarNavigationPolicy` (12),
  `HomeErrorPresentation` (10).
- No regression in Epic 1 / playback / parser suites.
- `git diff --check` clean on every commit.

---

## 9. Open debt (carried, not resolved by Epic 2)

| Debt | Owner | Note |
| --- | --- | --- |
| `DEBT-E0-001` ATS / local-network trust | Epic 1/5 | Untouched |
| `DEBT-E0-005` Swift 6 build truth | Epic 4/5 | Project still builds Swift 5 mode; new nav types now `nonisolated` |
| `DEBT-E0-006` UI automation gap | — | Manual UAT accepted for Epic 2 flows |
| `DEBT-E0-007` Accessibility automation/device gap | — | On-device capture deferred |
| `DEBT-E0-008` Performance baseline gap | — | Harness landed; numeric runs deferred |
| `DEBT-E1-PR1-004` Live Plex fixture | — | Live home/account UAT remains debt |
| `DEBT-E1-PR2-001` Sentry DSN ownership | Owner/Epic 5 | Untouched |
| `DEBT-E1-PR3-001` Local-network privacy copy | Epic 1/5 | Untouched |
| `DEBT-E1-PR10-001` Provider watchlist write contract | Epic 3 | Untouched; no provider writes added |
| `NET-026` / `NET-028` contained token-bearing media/search URLs | cross-epic | Not extended by Epic 2 |

Reduced by Epic 2: `DEBT-E0-002`/`NET-019` (Top Shelf token URL eliminated),
`DEBT-E0-004` (observability — Home error sink sanitized), `DEBT-E0-008`
(home/launch harness landed).

---

## 10. Accepted limitations

- On-device accessibility and numeric performance evidence are deferred to a
  pre-Epic-5 capture pass (`DEBT-E0-007`/`DEBT-E0-008`). Parity is capped at 4
  accordingly.
- No automated UI regression lane (`DEBT-E0-006`); manual UAT accepted.
- Live-account UAT constrained by `DEBT-E1-PR1-004`.
- Featured/discovery rows beyond Continue Watching + library Recently-Added were
  intentionally not expanded (live-data shape unverifiable locally); existing
  `HomeComposer`/library-hub composition is retained unchanged.

---

## 11. UAT required (before ship)

Manual UAT-E2-01..12 (`epic-2-decomposition.md` §15), in particular:
cold/warm launch within budget, Continue Watching resume position, Menu/back
from home/hero/rows, focus round-trips through overlays, empty/error surfaces,
Top Shelf deep-link landing, Reduce Motion, and VoiceOver pass. These need a
device/simulator session and are not claimed complete here.

---

## 12. Device validation still required

Home, Hero, Sidebar/Navigation, and Top Shelf on physical Apple TV:
VoiceOver labels/order, focus path round-trips, reduced-motion, contrast over
artwork, deep-link landing, and PERF-001/002/003/009/010 numeric runs.
Required before Epic 5 ship per the accessibility-matrix and performance-budget
review rules.

---

## 13. Recommendation

**Close Epic 2 with accepted debt.**

Every software exit-gate criterion is met: hero-first launch, deterministic
navigation and focus, normalised + sanitized states, secure Top Shelf, full
green test suite, and complete evidence/parity/accessibility/debt records. The
only outstanding items are on-device capture and numeric performance runs, which
the governance package already classifies as accepted, dated debt owned by the
pre-ship (Epic 5) pass — not Epic 2 implementation gaps.

Next epic: **Epic 3 — Apple TV Content Experience** (preview/detail/visual
language/watchlist/discover/universal details/trailers). Epic 3 **can begin**:
it depends on the Epic 2 Home/RenderState/Focus foundations now in place, and on
the `DEBT-E1-PR10-001` watchlist-write contract which Epic 3 owns. No Epic 2
work blocks it.

This recommendation is subject to Project Owner acceptance of the proposed
parity score changes (Score Change Rule 4) and Epic 5 pre-ship device/perf
validation.
