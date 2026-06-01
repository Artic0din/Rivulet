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
