# Epic 2 / Epic 3 Visibility & Adoption Audit

Date: 2026-06-01
Type: Audit-only (no code change). Read-only wiring verification via source grep.
Trigger: Epic 3 reported deliverables as "built/tested/committed" that were not
wired into live user-facing surfaces. This audit establishes LIVE vs PARTIALLY
LIVE vs BUILT-BUT-UNUSED with evidence before accepting closure/parity/Epic 4.

## Method + honesty note

Each symbol was grepped for references in live (non-test) source, excluding its
own definition file and `#Preview`. "LIVE" requires a reference from a
user-facing view/flow. The earlier `xcodebuild build`/`test` runs were real and
passed (533 unit tests on the tvOS sim), **but** those tests cover pure-policy
logic only — not SwiftUI views, integration, focus/animation, visual output, or
on-device behaviour. A green unit test on an un-wired component proves the logic,
not the feature. This audit corrects the resulting overstatement.

---

## Epic 2 Visibility Matrix

| Feature | Status | Commit(s) | Visible Surface | User Path | Debt ID | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| Hero-first Home | LIVE | `2211213` | `PlexHomeView` | Launch → Home | — | `showHomeHero` default true (PlexHomeView:20) |
| Hero selection policy | LIVE | `2211213` | `PlexHomeView.computeHubBackedHero` (:634) | Home hero | — | `HeroSelectionPolicy.select` called |
| Hero focus integration | LIVE | `2211213` | `HeroOverlayContent` | Home hero focus | — | `.defaultFocus` Play |
| Continue Watching promotion | LIVE | `69004a5` | `PlexHomeView.computeProcessedHubs` (:78) | Home rows | — | `HomeRowOrderingPolicy.order` + CW card a11y |
| Home row strategy | LIVE | `69004a5` | `PlexHomeView` | Home rows | — | CW pinned first |
| Sidebar/navigation refinement | LIVE | `b5dd93c` | `TVSidebarView` (:80,115,136) | Sidebar tab changes | — | `SidebarNavigationPolicy` wired |
| Focus restoration | LIVE | `9aa37cf` | `PlexHomeView` (:1339) | Home row refresh | — | `FocusRestorationPolicy.restoredFocusID` |
| FocusMemory adoption | LIVE | `9aa37cf` | `PlexHomeView`/`FocusMemory` | Home sections | — | recall/validIDs in use |
| Home loading state | LIVE | `638efd9` | `PlexHomeView` (:150 `ContentStateView`) | Home while loading | — | shared surface |
| Home empty state | LIVE | `638efd9` | `ContentStateView` `.homeEmpty` | Home, empty library | — | wired |
| Home error state | LIVE | `638efd9`/`86b776c` | `ContentStateView` + `HomeErrorPresentation` (:137) | Home on hub error | — | sanitized copy live |
| Home recovery (retry) | LIVE | `638efd9` | `ContentStateView` retry → `refreshHubs` | Home error → Try Again | — | deterministic retry focus |
| Top Shelf token-safe handoff | LIVE | `d508921` | `TopShelfPayloadBuilder` (PlexDataStore:1083) + extension | tvOS Top Shelf | — | local-file handoff |
| Home accessibility work | PARTIALLY LIVE | E2-PR3/4/5/7 | code wired; **no on-device VoiceOver capture** | Home (VoiceOver) | `DEBT-E0-007` | labels/focus live; device sign-off pending |
| Home performance instrumentation | LIVE (no numbers) | `638efd9` | `HomePerformanceTracer` (ContentView/PlexHomeView) | n/a (signposts) | `DEBT-E0-008` | emits signposts; **no captured numbers** |

**Epic 2: every functional deliverable is LIVE.** Two items are PARTIALLY LIVE
only because their *evidence* (device a11y, numeric perf) is deferred debt — the
code is wired and visible.

---

## Epic 3 Visibility Matrix

| Feature | Status | Commit(s) | Visible Surface | User Path | Debt ID | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| ContentDesignTokens | LIVE | `0d1b7f7` | `GlassRowStyle` (app-wide rows/buttons) | any glass row/button | — | tokens consumed by live styles |
| DetailMetadataCascade | LIVE | `7e0f215` | `MediaDetailView` (:967,975) | open any detail | — | metadata line order |
| PreviewMotionPolicy | LIVE | `0c590d9` | `PreviewOverlayHost` (:270,324,378,452) | open a row preview w/ Reduce Motion | — | structural motion gating |
| PreviewStateMachine (tests) | LIVE (pre-existing) | `0c590d9` | `PreviewOverlayHost` | preview exit/expand | — | I added tests only; logic pre-existed |
| Discover presentation states | LIVE | `e7d6d8a` | `DiscoverView` (:169,291) | Discover with no/loading content | — | calm empty/loading |
| CastImagePresentation + cast a11y | LIVE | `c9ba2b2` | `CastMemberCard`/`PersonCard` (:49,79) | detail → Cast & Crew | — | label + initials fallback |
| **ContentPresentationPolicy** | **LIVE (ADO-02)** | `1870830`, ADO-02 | Home Recently Added row (via `PlexContentCardMapper`) | Home → Recently Added | — | drives title/artwork/metadata of the landscape card |
| **LandscapeContentCard** | **LIVE (ADO-02, one row)** | `e077384`, ADO-02 | Home Recently Added row | Home → Recently Added | `DEBT-E3-PR7-001` (broader rows) | always-`.landscape` mode wired; other rows unchanged |
| **poster-to-landscape-on-focus** | **LIVE, geometry + stacking corrected (ADO-02C)** | `e077384` (ADO-02) → ADO-02C + stacking correction | Home Recently Added row | Home → Recently Added (focus a card) | `DEBT-E3-PR7-001` (broader rows) | `.posterExpandsToLandscape`: **poster-shaped footprint at rest (no black gutters)** → landscape composition drawn as an **overflow overlay** on focus; stable footprint = no row reflow. First attempt fixed gutters but the focused overflow drew BEHIND the next poster — corrected by moving `.zIndex(focused ? 1000 : 0)` to the **outermost** modifier of the realized row cell so the focused card draws above neighbours. Pending Ryan's on-device visual confirmation |
| ~~EpisodeContentCard~~ | **RETIRED (ADO-01B)** | `e53cf9f` → deleted `d6a274f`+ADO-01B | n/a | — | resolved | dead view + model machinery removed; production `EpisodeCard` is canonical |
| **EpisodeCardPresentation** | **LIVE (ADO-01)** | `e53cf9f`, `d6a274f` | production `EpisodeCard` in `MediaDetailView` | show → episode detail | — | episode label + combined VoiceOver summary sourced from policy |
| **ScheduleLabelPolicy** | BUILT BUT UNUSED | `e53cf9f` | none | — | new `DEBT-E3-PR10-001` | no hero/detail label consumer |

**Epic 3: the headline Content Presentation System visuals (landscape cards,
poster→landscape, episode cards, schedule labels) are BUILT BUT UNUSED.** The
live wins are the refactors/policies already attached to existing screens
(tokens via GlassRowStyle, detail cascade, preview reduce-motion, discover
states, cast a11y).

---

## Closure review

### Epic 2 → **CLOSE EPIC 2 WITH ACCEPTED DEBT** (unchanged)
Every functional deliverable is LIVE and user-visible. Remaining gaps are
evidence-only (on-device a11y `DEBT-E0-007`, numeric perf `DEBT-E0-008`) —
legitimately accepted debt, not unbuilt features. Closure stands.

### Epic 3 → **REOPEN EPIC 3**
The epic's defining scope — the Content Presentation System and its cards/labels
— is not in any user-facing flow. Under the governing rule ("policy/component/
model/test but not visible = NOT complete"), the headline deliverables are
incomplete. The live items are real but are mostly safe refactors of existing
surfaces, not the new content experience the epic promised. Recommend reopen and
complete the adoption slices below before re-closing.

(Alternative, if Project Owner prefers: CLOSE EPIC 3 WITH ACCEPTED DEBT, treating
the cards/labels as a dated follow-up. Not recommended — it repeats the pattern
that triggered this audit.)

---

## Parity score review

| Category | Old | Proposed | Visibility supports? | Recommendation |
| --- | --- | --- | --- | --- |
| Home | 3 | 4 | YES — hero-first/CW/states all live | Keep 4 (capped; device evidence pending) |
| Hero | 2 | 4 | YES — canonical hero live | Keep 4 |
| Navigation | 3 | 4 | YES — `SidebarNavigationPolicy` live | Keep 4 |
| Focus | 3 | 4 | YES — restoration live | Keep 4 |
| Top Shelf | 2 | 4 | YES — token-safe handoff live | Keep 4 |
| Detail | 3 | 4 | PARTIAL — cascade live, but cards/cast-images/episode cards not | **Reduce to 3** until detail card/episode adoption ships |
| Visual Language | 3 | 4 | PARTIAL — tokens live via GlassRowStyle; the *card system* that defines the look is unused | **Reduce to 3** (or hold at 3) until cards adopted |
| Preview | 4 | 4 (strengthened) | YES — reduce-motion live | Keep 4 |
| Accessibility | 2 | 3 | PARTIAL — cast/preview a11y live; episode/card a11y unused; no device capture | **Reduce to 2–3**; hold at 2 until device capture, or 3 on live-cast-a11y basis only |

All parity numbers remain **proposals pending Project Owner** regardless; this
review flags that Detail / Visual Language / Accessibility increases leaned partly
on un-wired features and should not be accepted at 4/3 until adoption ships.

---

## Adoption slice backlog (PLAN ONLY — not implemented)

| Adoption ID | Feature | Recommended PR | Est. scope | Dependencies | Risk | Why not previously adopted |
| --- | --- | --- | --- | --- | --- | --- |
| ADO-01 | EpisodeContentCard → detail seasons/episodes list | E3A-PR1 | Medium (replace existing episode row rendering in `MediaDetailView`) | `EpisodeCardPresentation` (built) | Med — focus/layout in 3.7k-line view; needs device check | Built additive; no device to validate focus/animation |
| ADO-02 | LandscapeContentCard + poster→landscape into Home/Library rows | E3A-PR2 | Large (row infra migration from `MediaPosterCard`) | `ContentPresentationPolicy`, `ContentCardModel` mapping from `MediaItem` | High — touches every row; focus restoration regressions | Same; broad migration, device validation required |
| ADO-03 | ScheduleLabelPolicy → hero/detail labels ("New"/"Season Finale") | E3A-PR3 | Small–Med (compute days-ago from Plex dates; render chip on hero/detail) | `ScheduleLabelPolicy` (built) | Low–Med — display-only; needs real date data to verify | No consumer wired; no live data fixture |
| ADO-04 | ContentPresentationPolicy → drive card style selection + a `ContentPresentationStyle` setting | E3A-PR4 | Med (settings model + wire into ADO-02 cards) | ADO-02 | Med — settings surface scope | Policy built; depended on cards being live first |
| ADO-05 | Cast/crew real-image parity confirmation on device | E3A-PR5 | Small (verification + any TMDb person-image enhancement, documented) | none | Low | Images already load; only device confirmation + optional enhancement deferred |
| ADO-06 | On-device a11y + numeric perf capture (Epic 2 + 3) | E5 pre-ship | Med (device session, captures) | physical Apple TV | Low | No device available this session (`DEBT-E0-007`/`008`) |

---

## Epic 4 gate → **NO (do not begin)**

Reasons:
1. Governance posture: Epic 3 is recommended for REOPEN; closing/parity are in
   question. Starting Epic 4 on an unsettled base repeats the audit trigger.
2. Pre-existing Epic 4 conditions (from `epic-4-decomposition.md` §8) are unmet:
   AVKit-first policy not ratified, no media corpus / device for the mandatory
   gate, and the playback stream-URL Sentry leak (`E0-OBS-002/003`) not yet
   scheduled.

Blocking items before Epic 4:
- Resolve Epic 3 reopen decision; ship ADO-01/02/03 (the core content-presentation
  adoption) or formally accept them as dated debt with Project Owner sign-off.
- Ratify AVKit-first policy; secure media corpus + Apple TV; schedule E4-PR1
  (stream-URL redaction) first.

---

## Recommended next action

1. **Accept this audit.** Treat Epic 3 as REOPEN (or explicitly accept the card/
   label deferral as dated debt — owner's call).
2. Adjust the parity scorecard: hold Detail/Visual Language/Accessibility at 3/3/2
   until ADO-01/02/03 ship.
3. Authorize the adoption slices one at a time, each validated **by you on the
   simulator/device** (the missing fair test), starting with **ADO-01 (episode
   cards in detail)** as the clearest visual win.
4. Keep Epic 4 gated until the blocking items clear.
