# Epic 3 — Apple TV Content Experience — Closure Report

Date: 2026-06-01
Owner: Epic 3 owner
Branch: `codex/epic-2-pr4-canonical-hero`
Status: **Complete with accepted debt** (recommend close; see §13)

Mirrors the Epic 1/2 closure-report structure. Satisfies the Epic 3
decomposition closure checklist (§15) and the expanded acceptance criteria
(§20.7 and §21.4).

> Revision (E3-PR12): this report supersedes the initial E3-PR9 closure. Epic 3
> was reopened by Product Direction #2 (decomposition §21) to add episode cards,
> cast/crew images, and schedule/air-date labels — delivered in E3-PR10/PR11 and
> reflected below.

---

## 1. Objective status

Goal: make content browsing, expansion, and selection feel first-party quality,
with Apple TV as the faithfulness benchmark (distinct, no Apple branding/trade-
dress/private-API/integration claims). Epic 3 also owns the full Content
Presentation System.

| Acceptance criterion (§20.7) | Status | Basis |
| --- | --- | --- |
| Content presentation system documented | Met | `content-design-language.md` + decomposition §20 |
| Content presentation policy exists | Met | `ContentPresentationPolicy` (E3-PR6) |
| ≥1 production-ready presentation style | Met | `LandscapeContentCard` (E3-PR7) |
| Landscape artwork supported or deferred | Met (implemented; broad adoption debt) | E3-PR7 + `DEBT-E3-PR7-001` |
| Logo presentation supported or deferred | Met | `TitleTreatmentPolicy` + card title treatment |
| Metadata hierarchy implemented | Met | `MetadataHierarchyPolicy` + `DetailMetadataCascade` |
| Technical badges implemented or deferred | Met | `TechnicalBadgePolicy` |
| Content ratings implemented | Met | `ContentRatingPresentation` |
| Runtime presentation implemented | Met | `RuntimeFormatter` |
| Poster→landscape mode implemented or deferred | Met (implemented; adoption debt) | E3-PR7 `.posterExpandsToLandscape` + `DEBT-E3-PR7-001` |
| Accessibility evidence exists | Met (code/policy; device deferred) | E3-PR8, matrix A11Y-005..010 |
| Performance evidence exists | Partial | No focus-time fetch verified; numeric capture `DEBT-E0-008` |
| Focus restoration evidence exists | Met | `FocusRestorationPolicy`/`PreviewStateMachine` tests |
| No Apple branding/trade-dress/private-API | Met | scope scans; own Glass identity |
| Episode cards Apple-TV-quality or deferred (§21.4) | Met (component + policy; adoption debt) | E3-PR10 + `DEBT-E3-PR7-001` |
| Cast/crew images supported or deferred (§21.4) | Met | `PersonCard` images + `CastImagePresentation` (E3-PR11) |
| Air-date/availability label policy or deferred (§21.4) | Met | `ScheduleLabelPolicy` (E3-PR10) |

All software-buildable criteria met. Performance numeric capture and on-device
accessibility remain accepted, dated debt (`DEBT-E0-007`/`DEBT-E0-008`), capping
parity at 4, not blocking closure.

---

## 2. PR slices completed

| Slice | Commit | Summary |
| --- | --- | --- |
| E3-PR1 | `494d6b1` | Decomposition + content-surface baseline audit |
| E3-PR2 | `0d1b7f7` | Canonical `ContentDesignTokens`; `GlassRowStyle` refactor; `ScaledDimensions` nonisolated |
| E3-PR3 | `0c590d9` | Preview reduce-motion gating + tested `PreviewStateMachine`/`PreviewMotionPolicy` |
| E3-PR4 | `7e0f215` | Deterministic `DetailMetadataCascade` |
| E3-PR5 | `e7d6d8a` | Calm Discover loading/empty states; `DEBT-E1-PR10-001` carried |
| (scope) | `e65042d` | Decomposition expanded to Content Presentation System |
| E3-PR6 | `1870830` | `ContentPresentationPolicy` (style/title/artwork/runtime/rating/badges/hierarchy) |
| E3-PR7 | `e077384` | `LandscapeContentCard` (landscape + poster→landscape-on-focus) |
| E3-PR8 | `2fd2a11` | Content accessibility review + test-count corrections |
| E3-PR9 | `ab0dd79` | Initial closure (superseded by this revision) |
| E3-PR10 | `e53cf9f` | Episode cards + `ScheduleLabelPolicy` (Product Direction #2) |
| E3-PR11 | `c9ba2b2` | Cast/crew VoiceOver + initials fallback (Product Direction #2) |

Each slice is independently reviewable, reversible, build-green, with evidence
IDs. None modifies an Epic 1 boundary, playback, project setting, deployment
target, Swift version, the app name, or PR #1 CI/review setup.

---

## 3. Files changed by slice

- **E3-PR2**: `Views/Components/ContentDesignTokens.swift` (new), `GlassRowStyle.swift`, `Services/UIScale.swift`, tests, design-language doc.
- **E3-PR3**: `Views/Media/PreviewMotionPolicy.swift` (new), `PreviewOverlayHost.swift`, `PreviewTransitionTests` (new).
- **E3-PR4**: `Views/Media/DetailMetadataCascade.swift` (new), `MediaDetailView.swift`, tests.
- **E3-PR5**: `Views/Discover/DiscoverPresentation.swift` (new), `DiscoverView.swift`, `ContentStateView.swift`, tests.
- **E3-PR6**: `Views/Components/ContentPresentationPolicy.swift` (new), tests, design-language doc.
- **E3-PR7**: `Views/Media/LandscapeContentCard.swift` (new), `ContentCardAccessibilityTests` (new), debt entry.
- **E3-PR8 / docs**: closure/review/decomposition docs, evidence/parity/a11y/debt registers, CHANGELOG.

---

## 4. Apple TV parity score changes (proposed, pending Project Owner)

| Category | Was | Proposed | Slice | Capped reason |
| --- | --- | --- | --- | --- |
| Visual Language | 3 | 4 | E3-PR2 | App-wide token adoption + device comparison set |
| Detail | 3 | 4 | E3-PR4 | Universal-details + related-content + device review |
| Preview | 4 | 4 | E3-PR3 | Strengthened (reduce-motion, tested exit); device frame-timing for 5 |
| Accessibility | 2 | 3 | E3-PR8 | On-device VoiceOver/contrast capture for 4+ |

Scores are proposals; Score Change Rule 4 requires Project Owner acceptance.
Printed scorecard cells unchanged until then.

---

## 5. Accessibility status

A11Y-005..010 code/policy reviewed (E3-PR8): preview reduce-motion + exit/focus,
detail cascade order, discover empty/loading. New content card exposes a combined
VoiceOver element. **On-device VoiceOver/focus/contrast capture deferred
(`DEBT-E0-007`)** and required before Epic 5. Not falsely marked complete.

---

## 6. Performance status

No content change adds network or heavy image work on focus movement (the new
card takes pre-resolved URLs; preview prefetch window unchanged). Numeric capture
deferred (`DEBT-E0-008`).

---

## 7. Security / privacy status

No new network host/endpoint. Artwork/logo URLs flow through the existing cached
image path; the presentation policies carry no tokens. No provider/auth/token
change. No watchlist mutation added. Clean for changed surfaces (E0-G01/G02/G03).

---

## 8. Testing / build status

- `xcodebuild build`: exit 0, 0 errors (UDID `F8288707-…`). New value/policy
  types `nonisolated`; no new isolation warnings.
- Full suite: **533 tests passed, 0 failed** (+72 over Epic 2's 461).
- Epic 3 pure-policy suites: `ContentDesignTokensTests` (5),
  `PreviewStateMachineTests` (9), `PreviewMotionPolicyTests` (3),
  `DetailMetadataCascadeTests` (11), `DiscoverPresentationTests` (4),
  `ContentPresentationPolicyTests` (15), `ContentCardAccessibilityTests` (4),
  `ScheduleLabelPolicyTests` (9), `EpisodeCardPresentationTests` (6),
  `CastImagePresentationTests` (6).
- No regression in Epic 1/2 or playback/parser suites. `git diff --check` clean
  on every commit.

---

## 9. Open debt

| Debt | Disposition |
| --- | --- |
| `DEBT-E3-PR7-001` Landscape card production adoption | New; accepted (broad row adoption + device validation) |
| `DEBT-E1-PR10-001` Provider watchlist write contract | Carried (needs Epic 1 boundary change — forbidden this epic) |
| `DEBT-E0-007` Accessibility/device capture | Carried |
| `DEBT-E0-008` Performance numeric capture | Carried |
| `DEBT-E0-005` Swift 6 build truth | Carried (new value types `nonisolated`) |
| `DEBT-E0-006` UI automation gap | Carried (manual UAT accepted) |
| `DEBT-E1-PR1-004` Live fixture | Carried |

---

## 10. Accepted limitations

- `LandscapeContentCard` is implemented + tested but not yet wired into
  production rows (`DEBT-E3-PR7-001`); needs on-device focus/animation review.
- On-device accessibility + numeric performance deferred (`DEBT-E0-007/008`).
- Watchlist write contract unresolved within Epic 3 constraints
  (`DEBT-E1-PR10-001`).

---

## 11. UAT required (before ship)

Manual: poster→preview→exit focus round-trip; detail metadata hierarchy reads
correctly; discover empty/loading; Reduce Motion across preview/cards; VoiceOver
on content cards and detail. Device/simulator session required; not claimed
complete here.

---

## 12. Device validation still required

Preview, Detail, and (on adoption) `LandscapeContentCard` on physical Apple TV:
VoiceOver labels/order, focus round-trips, reduced motion, contrast over artwork,
and PERF-009/010 numeric runs. Required before Epic 5.

---

## 13. Recommendation

**Close Epic 3 with accepted debt.**

The Content Presentation System is documented and implemented behind a
centralized, tested policy layer; a production-ready presentation style exists;
metadata hierarchy, ratings, runtime, badges, logos, and artwork fallback are
implemented; preview transitions are reduce-motion-safe and test-locked; the
detail cascade is deterministic; Discover has calm failure states. The full
suite is green (511/0). Outstanding items are on-device capture, numeric
performance, and the watchlist-write boundary — all accepted, dated debt owned
by later passes, not Epic 3 implementation gaps.

Next: **Epic 4 — Playback Excellence** (planning delivered alongside this
report; implementation NOT started). Epic 4 **can begin** after Project Owner
acceptance of the Epic 4 plan; nothing in Epic 3 blocks it.

Subject to Project Owner acceptance of proposed parity changes (Rule 4) and Epic
5 pre-ship device/perf validation.

---

## 14. Closure pass revision — ADO-01…06 adoption (2026-06-01)

This report's §1–13 reflect the E3-PR12 state. After it, the **visibility &
adoption audit** found that several Epic-3 surfaces were BUILT BUT UNUSED (cards,
labels, policies existed but were not wired into production), which is what
reopened Epic 3. The ADO slices closed that gap. This section records the final
adopted state and re-affirms closure.

### 14.1 ADO slices (all live, branch `codex/epic-2-pr4-canonical-hero`)

| Slice | Commit | Adopted into production |
| --- | --- | --- |
| ADO-01 / ADO-01B | (E3) | Episode-card label + combined VoiceOver via `EpisodeCardPresentation`; dead parallel `EpisodeContentCard` retired |
| ADO-02 → shelf settle | (E3) | Recently Added is a live `LandscapeContentCard` shelf; poster→landscape interaction dropped by product decision (dead expansion code removed) |
| ADO-03 | (E3) | Content Status Label System (`ContentStatusLabel`/`ContentStatusPolicy`/`ContentStatusPlacement`) — architecture + placement + tests; retired the narrow `ScheduleLabelPolicy` |
| ADO-04 | `edf7528` etc. | TMDb-backed status labels LIVE on Home hero + detail; `includeGuids=1` everywhere; hero auto-rotates |
| ADO-05 | `ae622f3` | Episode-card status labels LIVE (Season Finale / New Episode Today / New Episode), Plex-backed, placement-gated, specials-guarded |
| ADO-06 | `8c79f96` | Adaptive artwork-driven backdrop tint (hero + detail) + unified rounded `MetadataBadge` for rating + technical badges |
| Apple-TV audit | `47b907a` | Benchmark audit (no code) classifying every reference idea |

### 14.2 Built-but-unused recheck

No meaningful BUILT-BUT-UNUSED Epic-3 items remain:

- `LandscapeContentCard` — **live** (Recently Added shelf).
- `ContentStatusLabel` system — **live** on hero, detail, and episode cards (all
  three non-shelf placements).
- `EpisodeCardPresentation` — **live** on the production episode card.
- `TechnicalBadgePolicy` / `MetadataBadge` — **live** on landscape cards + detail
  + hero (rating).
- `DetailMetadataCascade`, `PreviewMotionPolicy`, `ContentPresentationPolicy` —
  **live** on detail / preview / cards.
- The superseded `ScheduleLabelPolicy` and the dropped poster-expansion geometry
  were **removed**, not left dormant.

### 14.3 Parity (ADO-era, replaces §4 proposal — Rule 2 caps all at 4 while
`DEBT-E0-007/008` are open; none raised to 5)

| Category | Printed | Recommended final | Justification | Evidence |
| --- | --- | --- | --- | --- |
| Visual Language | 3 | **4** | Canonical `ContentDesignTokens` + adaptive tint + one shared `MetadataBadge` + landscape shelf + status chips = one deliberate design language across home/detail/cards | `E3-PR2-TOKENS-001`, `ADO-06-TINT-001`, `ADO-06-BADGE-001`, `ADO-06-HIER-001` |
| Detail | 3 | **4** | Deterministic metadata cascade + live episode cards + cast/crew spotlight + content-status chip + episode-card status + rating badges + adaptive tint; related-content row present | `E3-PR4-CASCADE-001`, `ADO-01-ADOPT-001`, `ADO-05-ADOPT-001`, `ADO-06-BADGE-001` |
| Hero (Epic 2-owned; Epic 3 reinforced) | 2→(4 proposed) | **4** | Canonical hero (E2-PR4) now also carries the TMDb status chip (ADO-04), auto-rotation, adaptive tint + rating badge (ADO-06) | `E2-PR4-CANONICAL-001`, `ADO-06-TINT-001` |
| Preview | 4 | **4 (hold)** | Unchanged by ADO; reduce-motion-safe + test-locked already | `E3-PR3-MOTION-001`, `E3-PR3-DETERMINISM-001` |
| Accessibility | 2→(3 proposed) | **3 (hold, strengthened)** | Status labels fold into combined VoiceOver; episode-card status folded in; tint a11y-gated. Capped at 3 — no on-device VoiceOver/contrast capture yet (Rule 3) | `E3-PR8-A11Y-001`, `ADO-05-A11Y-001`, `ADO-06-TINT-A11Y-001` |

Scores are deliberately **not** inflated: every category is held at ≤4 because
on-device capture (`DEBT-E0-007`/`DEBT-E0-008`) is the gate to 5, and
Accessibility stays at 3 because on-device VoiceOver/contrast runs are absent.

### 14.4 Debt classification (closure)

| Debt | Classification | Note |
| --- | --- | --- |
| `DEBT-E0-007` Accessibility device capture | **Epic 5 (pre-ship)** — accepted | Caps parity at 4; not an Epic-3 closure blocker |
| `DEBT-E0-008` Performance numeric capture | **Epic 5 (pre-ship)** — accepted | Harness exists (`HomePerformanceTracer`); numeric runs outstanding |
| `DEBT-E3-PR7-001` Broader card-row + badge spread | **Accepted debt / future backlog** | ≥1 production row uses cards; badges now on landscape + detail + hero |
| `DEBT-E3-ADO03-001` Renewed-no-date + on-device label validation | **Accepted debt** — renewed-no-date = future backlog; validation = Epic 5 | Episode-card + decode portions DONE |
| `DEBT-E3-APPLEREF-001` Adaptive tint + rating badge | **Substantially resolved** (ADO-06); on-device confirmation = Epic 5 | Tint limited to hero+detail by design |

No closure blockers. No debt falsely closed.

### 14.5 Final disposition

**CLOSE EPIC 3 WITH ACCEPTED DEBT.** All decomposition acceptance criteria are
met or implemented and adopted in production; the visibility-audit reopen
findings are resolved; the only outstanding items are on-device accessibility +
numeric-performance capture (Epic 5 pre-ship gate) and minor future-backlog
adoption — all accepted, dated debt, none an Epic-3 implementation gap.

### 14.6 Epic 4 gate — **NO (do not begin yet)**

Epic 3 closure imposes **no** blocker on Epic 4, but Epic 4's own entry
preconditions are unmet:

1. **AVKit-first policy not ratified** (still a plan in `epic-4-decomposition.md`,
   not Project-Owner-accepted).
2. **Playback stream-URL Sentry leak** (`E0-OBS-002`/`E0-OBS-003`, security)
   must be scheduled as the FIRST Epic-4 slice (E4-PR1 redaction) before other
   playback work — the visibility audit's standing condition.
3. **No media-validation corpus + physical Apple TV** secured for the mandatory
   playback gate.

Not blockers (already in hand): chapter navigation is already implemented in the
player (`includeChapters=1` + chapter UI) — Epic 4 validates/polishes, not
builds; display badges + detail trailer playback exist (capability badges + hero
silent preview remain Epic 4).

**First Epic 4 slice when authorised:** E4-PR1 — playback stream-URL / Sentry
redaction (security-first), ahead of any AVKit/route work.
