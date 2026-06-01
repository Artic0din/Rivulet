# Apple TV Reference Implementation Audit (Epic 3)

Status: audit / classification / roadmap-alignment pass.
No code changes in this pass.
Author pass date: 2026-06-01.

## 0. Source verification status

Ryan supplied Apple TV / Apple partner documentation links plus detailed implementation notes.
This audit draws primarily from those supplied notes and from a direct read of the current Rivulet codebase.

Live Apple documentation verification was **partial**:

| Source | Reachable this pass | Notes |
| --- | --- | --- |
| `help.apple.com/itc/tvpumcstyleguide` (UMC style guide) | Yes | Confirms structured-metadata delivery; premiere date must be the actual airing date, not date-added; labels read as system-generated from structured data, not free-typed strings. |
| `tvpartners.apple.com/support/3718-coming-soon-overview` | Yes | Confirms Coming Soon is **Apple Subscription Video partner-only**, requires an Apple-initiated qualification process, requires at least one playable trailer/extra, uses PST (UTC-08:00) windows, and that episodes are not needed until seven days before availability. |
| Remaining `help.apple.com/itc/*` and `tvpartners.apple.com/support/*` links (video/audio asset guide, tv style guide, artwork requirements, channels art spec, UMC specifications, metadata requirements) | Not individually re-fetched this pass | Most `tvpartners.apple.com` support pages are partner-login-gated and not reliably fetchable; treated from Ryan's supplied notes. |

Where a claim below rests only on Ryan's notes (not a live Apple read), it is treated as a **useful design concept**, not a verified partner requirement.

---

## 1. Executive summary

The Apple TV app is a **quality benchmark**, not a clone target.
The single most important structural insight, confirmed live against the UMC style guide and Coming Soon overview, is that Apple's editorial and scheduling labels ("New Season \<date\>", "New Episodes \<day\>", "Coming \<date\>") are **system-generated from structured timeline metadata** submitted through partner feeds — partners do not type those strings.
Rivulet already follows the correct shape of this idea: it derives labels from data (Plex air dates, TMDb status), never from hardcoded copy.

Useful to Rivulet (and already largely built):

- Data-derived content status labels (Content Status Label System — live on hero + detail).
- Technical format badges chosen by priority (TechnicalBadgePolicy — live on landscape cards).
- Continue Watching / Up Next prominence (Epic 2 — live).
- Cast & crew spotlight with initials fallback (Epic 3 PR11 — live).
- Trailer playback from detail (Plex Extras — live, button-triggered).
- Chapter navigation with thumbnails in the player (`includeChapters=1` — already implemented).
- Deterministic hero auto-rotation (HeroRotationPolicy — live).

Useful but **not yet built** (genuine gaps, all safe and Plex/TMDb-powered):

- Adaptive poster-colour background tint ("Liquid Glass" immersion) on media detail / hero — currently uses static backdrops, no dominant-colour extraction.
- Apple-style **rating badge** styling — content rating is decoded and rendered, but as plain text, not a clean rounded badge consistent with the technical badges.
- Episode-card status labels — the Content Status Label System is wired for `episodeCard` placement but not yet adopted on live episode cards.
- "Another Season Is Coming" (renewed, no date) status case — not modelled.
- Broader use of Plex `includeRelated` for "More Like This" / director / similar rows (current recommendations come from a bespoke service, not the Plex related hubs).

Partner-only / out of scope (reject): Apple branding, Apple Originals flag, Apple TV+ tab/labels, "#1 Show on Apple TV" and any ranking/editorial-placement claim, Universal Search / Up Next system integration, Transporter / XML feed validation, partner entitlements, Coming Soon as an Apple feature (it is qualification-gated and feed-driven).

Epic mapping at a glance:

- **Epic 3** (content experience): episode-card status labels, renewed-no-date model case, adaptive tint, rating-badge styling, broader related-row adoption, badge adoption on more card types.
- **Epic 4** (playback excellence): playback-capability badges (true DV/Atmos delivery), hero silent trailer auto-preview, chapter-nav polish/validation.
- **Epic 5** (release validation): on-device accessibility + performance capture for all of the above.
- **Out of scope**: all Apple-partner-feed and Apple-branding items in §16.

Recommendation (detail in §20): keep **ADO-05 = episode-card status labels** (smallest, fully Plex-backed, completes the label system across placements, zero TMDb/playback risk), optionally folding in the pure-model "Another Season Is Coming" case since it is documentation/model-only.
Epic 3 can close after episode-card adoption + on-device capture; the adaptive-tint and rating-badge polish are strong ADO-06 candidates but not blockers.
Epic 4 should not begin until Epic 3 closes.

---

## 2. Guardrails

These hold for every item in this audit and every downstream slice it informs.

- Apple TV is a **benchmark**, not a clone target. Rivulet remains a distinct Plex / TMDb / local-metadata tvOS client.
- **No Apple branding.** No Apple wordmark, logos, icons, or artwork.
- **No Apple trade dress.** Do not reproduce Apple-proprietary layout chrome to pass as the Apple TV app.
- **No Apple ranking claims.** Never "#1 Show on Apple TV", "Top 10", "Trending on Apple TV", or any editorial-placement claim Rivulet cannot itself verify from its own data.
- **No Apple Original badge** and **no Apple TV+ labels/branding/tab.**
- **No private Apple APIs.**
- **No Universal Search / Up Next system integration claims** — those require partner entitlements Rivulet does not hold.
- **No XML / Transporter / Apple feed implementation** unless Rivulet ever becomes an actual Apple partner app (it is not, and there is no plan for it to be).
- All Rivulet behaviour must be powered by **Plex, TMDb, local metadata, or existing app state** — never by importing partner-feed rules as application requirements.
- Standing project constraints persist: no push, no merge, no Epic 4 start, no rename to Arc, no project-setting changes, no playback changes, no Epic 1 provider/auth/token/watch-state boundary changes.

---

## 3. Reference categories matrix

Implementation status legend: **Live** (in production paths), **Partial** (built but not fully adopted), **Gap** (not built), **Done-elsewhere** (already implemented outside Epic 3, e.g. player), **Reject** (partner-only / out of scope).

| Reference area | Apple TV / partner concept | Rivulet equivalent | Data source | Owning epic | Status | Risk | Recommendation |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Content status labels | System-generated scheduling/editorial labels from feed timeline metadata | `ContentStatusLabel` / `ContentStatusPolicy` / `ContentStatusPlacement` | Plex air dates + TMDb status | 3 | Live (hero + detail); Partial (episode cards) | Low | Adopt on episode cards (ADO-05); add renewed-no-date case |
| Artwork requirements | Poster/landscape/hero/clear-logo/cast art specs | `LandscapeContentCard`, `MediaPosterCard`, `HeroBackdropLayer`, `CachedAsyncImage` | Plex `thumb`/`art`/logos, TMDb image paths | 3 | Live (poster + landscape shelves) | Low | Audit art-vs-thumb selection consistency (§5); no spec import |
| Metadata quality | Clean, superlative-free, structured metadata | `DetailMetadataCascade`, content presentation policies | Plex/TMDb metadata | 3 | Live | Low | Keep deriving, never hardcode editorial copy |
| Technical format badges | System-detected 4K/HDR/DV/Atmos/5.1 badges | `TechnicalBadgePolicy` + `ContentPresentation` | Plex stream attributes via `MediaSource` | 3 (display) / 4 (capability) | Live on landscape cards | Medium | Truthful display badges only; capability badges are Epic 4 |
| Up Next / Continue Watching | Resume + next-episode + recency-bump queue | `ContinueWatchingCard`, Plex hubs | Plex Continue Watching / on-deck; Epic 1 watch state | 1 (ownership) / 2 (surface) | Live | Low | No change — Epic 1 owns watch state |
| Hero / top carousel | Rotating landscape hero, optional silent preview | Hero overlay + `HeroRotationPolicy` | Plex hubs + TMDb status | 2 (built) / 4 (preview) | Live (rotation); Gap (silent preview) | Low/Med | Keep rotation; silent preview deferred to Epic 4 |
| Adaptive visual language / Liquid Glass | Poster-colour-aware blurred backdrops, glass materials | `ContentDesignTokens`, `GlassRowStyle` | Plex art + on-device colour extraction | 3 | Partial (glass materials); Gap (colour tint) | Med (perf/contrast) | Candidate ADO-06; measure perf + contrast |
| Focus & card behaviour | Native parallax focus, drop shadow, density | SwiftUI `.card` button style + design tokens | n/a (system) | 3 | Live | Low | Keep native `buttonStyle(.card)`; do not hand-roll parallax |
| Channels / brand hubs | Studio/network landing pages | (none) — Plex `studio`/collections available | Plex studio/network/collections/labels | 3/5 (future) | Gap | Med (trade dress) | Future feature; avoid brand colours/logos |
| Tab structure | Search / Home / TV+ / Library | Sidebar: Search, Home, Library, Live TV, Settings (+ Discover, Music) | App nav | 2 (settled) | Live | Low | No restructure; never an "Apple TV+" tab |
| Contextual rows | More Like This / cast / director rows | `recommendedRow` + `PersonalizedRecommendationService`; `castCrewRow` | Plex relations + bespoke recs | 3 | Live (cast); Partial (related) | Low | Consider Plex `includeRelated` similar/director hubs |
| Trailers / extras | Auto-play top-shelf preview; detail trailer | Detail "Play Trailer" via Plex Extras; `trailerURL` | Plex Extras (`extraType==1`/`subtype=="trailer"`) | 3 (detail) / 4 (preview) | Live (detail button) | Med (autoplay) | No silent autoplay this pass; Epic 4 |
| More Like This recommendations | Pre-calculated related hub | `PersonalizedRecommendationService`, `relatedShowRatingKey` | Plex + bespoke service | 3 | Partial | Low | Evaluate `includeRelated=1` for parity/perf |
| Cast & crew spotlights | Circular headshots, tap-through filmography | `castCrewRow`, `MediaPerson` | Plex `Role`/`Director` | 3 | Live | Low | Tap-through filmography is a future enhancement |
| Content ratings / advisories | Rounded rating badge beside technical badges | `contentRating` text on hero + detail | Plex `contentRating` | 3 | Partial (text only) | Low | Style as a badge to match technical badges (ADO-06) |
| Chapter navigation | Scrub-up chapter strip with thumbnails | Player chapter UI + thumbnails | Plex `includeChapters=1` + `Chapter[]` | 4 | Done-elsewhere (player) | Low | Validate/polish in Epic 4; no Epic 3 work |
| Image caching / downscaling | Server-side downscale, safe sizes | `/photo/:/transcode`, `CachedAsyncImage`, `ImageCacheManager` | Plex photo transcode | 3 | Live (server downscale) | Low | Token-bearing URL hygiene is existing debt (KF-E0-002) |
| Playback controls | Floating glass player controls | `PlayerControlsOverlay` + RPlayer/AVPlayer | App player | 4 | Done-elsewhere | n/a | Out of Epic 3 scope; do not touch playback |
| Coming Soon content | Qualification-gated upcoming pages from feeds | `comingSoon`/`premieres` labels from TMDb | TMDb upcoming dates | 3 | Live (label only) | Low | Label-only is correct; never the Apple feed feature |

---

## 4. Content status labels

The current system (`Rivulet/Views/Components/ContentStatusLabel.swift`) models:

- Current / past-facing (Plex-backed): `seasonFinale`, `episodeAvailableToday`, `newEpisode`, `allEpisodesAvailable`, `recentlyAdded`.
- Future-facing (TMDb-backed): `premieres(Date)`, `returns(Date)`, `newSeason(Date)`, `newEpisodeWeekly(Weekday)`, `comingSoon(Date)`.
- Placements: `hero`, `detail`, `episodeCard`, `shelf`. Kinds: `movie`, `show`, `season`, `episode`.

Classification of the requested label set:

| Label | Class | Basis |
| --- | --- | --- |
| All Episodes Available | **A. Already supported** | `allEpisodesAvailable`, live; from TMDb Ended/Canceled + `!in_production`. |
| New Episode Every Friday | **A. Already supported** | `newEpisodeWeekly(.friday)`, live; weekday of upcoming episode when last→next gap ≤ 14 days. |
| New Season 06 August | **A. Already supported** | `newSeason(Date)`, live; rendered "dd MMMM" (UTC). Season-0 specials guarded. |
| Returns 12 September | **A. Already supported** | `returns(Date)`, live; upcoming episode after a long break. |
| Premieres 06 August | **A. Already supported** | `premieres(Date)`, live; series not yet aired (`first_air_date` in future). |
| Coming Soon | **A/B. Supported** | `comingSoon(Date)` for unreleased movies; dated when TMDb `release_date` known. Dateless "Coming Soon" is a trivial render variant if ever needed. |
| Another Season Is Coming | **D. Requires inference policy** | Renewed series (`status == Returning Series`, `in_production == true`) with **no** `next_episode_to_air` date. New no-date case + classify rule + tests. Pure model/test, no new data. |
| Season Finale | **A/B. Supported with current Plex data** | `seasonFinale` exists; Plex-derivable from `index == leafCount` on the last episode. Not yet adopted on episode cards (= ADO-05). |

Classification key: A already supported · B supported with current Plex/TMDb data · C requires TMDb model expansion · D requires inference policy · E should not be implemented.

There are currently **no class-C gaps** — the ADO-04 decode (`TMDBStatusDetail`) already covers the required TMDb fields.

**Explicitly rejected (class E):**

- "#1 Show on Apple TV" / any numeric ranking — Rivulet cannot verify platform ranking.
- "Apple Original" / `isOriginal` premium-branding layout — Apple-only flag.
- "Apple TV+" branding / labels.
- Editorial superlatives ("the best", "thrilling finale") — the UMC style guide strips these; Rivulet must keep labels factual and data-derived.
- Any platform-exclusive claim Rivulet cannot verify from its own metadata.

---

## 5. Artwork strategy

Apple's artwork discipline maps cleanly to Rivulet without importing pixel specs.

| Artwork role | Apple principle | Rivulet today | Recommendation |
| --- | --- | --- | --- |
| Poster (2:3) | Standard movie/show tiles | `MediaPosterCard` (poster shelves) | Keep poster shelves poster-based. |
| Landscape / backdrop (16:9) | Editorial / recently-added / sports rows | `LandscapeContentCard` (full-bleed `art ?? thumb`) | Landscape shelves correctly prefer `art`, fall back to `thumb`. |
| Hero | Wide cinematic banner | `HeroBackdropLayer` | Prefer `art`; this is correct. |
| Clear logo / title art | Title logo over art | Logo overlay on landscape/hero | Keep logo with text fallback. |
| Cast / crew imagery | Circular headshots | `castCrewRow` + initials fallback (PR11) | Done. |
| Brand / network imagery | Channel logos | (none) | Defer with Channels feature (§10); trade-dress risk. |
| Placeholder / fallback | Graceful empty art | `CachedAsyncImage` phases + initials | Done. |
| Safe sizing / downscaling | Server-side downscale, Top Shelf size limits | `/photo/:/transcode` (Plex resizes server-side) | Already correct; see §15. |

Where Rivulet already has the right artwork: poster shelves (poster), landscape shelves and hero (art/backdrop), cast (headshots with initials fallback).
Where it could use the **wrong** artwork: any place a poster (`thumb`) is shown where a backdrop (`art`) is the Apple-correct choice, or vice versa — recommend a one-pass consistency check (display-only, no fetching change), not a rewrite.
Top Shelf image safety already constrains that surface (Epic 2 PR2 hands off local files, secret-free) and must not regress.

No image changes in this pass.

---

## 6. Technical format badges

`TechnicalBadgePolicy` (in `ContentPresentationPolicy.swift`) already implements the Apple-style "at most one badge per dimension, canonical order" rule:

- Order: resolution → video format → audio format.
- `videoPriority = ["Dolby Vision", "HDR10+", "HDR10", "HDR"]`.
- `audioPriority = ["Dolby Atmos", "Atmos", "DTS:X", "TrueHD", "DTS-HD MA", "DTS-HD", "7.1", "5.1"]`.
- Adopted on `LandscapeContentCard` via `PlexContentCardMapper`, sourced from `MediaSource` (Plex stream attributes: `videoResolution`, `videoProfile`/codec, audio codec/channel layout).

Classification:

- **Epic 3 (detail/card display badges):** what a file *contains* — 4K / HDR / HDR10+ / Dolby Vision / Atmos / 7.1 / 5.1 — derived from Plex stream metadata. Already live on landscape cards; safe to extend to detail and other card types.
- **Epic 4 (playback-capability badges):** what the *active route can actually deliver* on this device/output. A file's DV/Atmos metadata does **not** guarantee the chosen route (`ContentRouter`) and the connected display/AVR can play it back. Capability badges must be gated on the resolved playback plan, not file metadata — Epic 4 only.
- **Unsafe / avoid:** claiming Dolby Vision / Atmos when Plex stream metadata does not support it; inferring playback capability from file metadata alone; any badge that could mislead about what the user will actually see/hear.

Content-rating badge styling is covered in §3 / §18 (rating is decoded and rendered as text today; styling it as a rounded badge is Epic 3 polish).

---

## 7. Up Next / Continue Watching logic

Apple's Up Next rules and their Rivulet mapping:

| Apple rule | Rivulet mapping | Status |
| --- | --- | --- |
| Resume in-progress with progress bar | `ContinueWatchingCard` + Plex view offset | Live (Epic 2 PR5 pinned it most-prominent, with full VoiceOver). |
| Next episode replaces finished one | Plex on-deck / Continue Watching hub semantics | Live (Plex-driven). |
| Recency bump for new episode in tracked series | Plex hub ordering | Live (server-ordered). |
| Tracked-series behaviour | Plex on-deck | Live (server-owned). |
| Stale progress / watched state | Plex watch state | Owned by Epic 1. |

Watch-state ownership lives behind the **Epic 1 boundary** (`PlexWatchlistService` / Plex timeline + watch state, `PlexProvider`).
This audit makes **no** recommendation that touches that boundary.
Epic 2 already completed the Home surface (prominent Continue Watching, VoiceOver).
Remaining is on-device validation only — no new logic.

---

## 8. Hero / carousel / auto-rotation

| Apple behaviour | Rivulet | Status |
| --- | --- | --- |
| Rotating hero | `HeroRotationPolicy` — deterministic ~10s, focus does **not** pause rotation | Live. |
| Content priority | Inline hero selection (Continue Watching → featured → recently added) | Live, but **not** an extracted/named policy. |
| Manual next/previous | Manual Next resets timer | Live. |
| Focus pause/resume | Rotation continues while focused; only slide content swaps, button row stays | Live (intentional, matches a native hero). |
| Optional silent video preview | (none) | Gap → Epic 4. |
| Status label placement | `ContentStatusLabel` chip above title on hero | Live. |

Note for accuracy: the brief referenced a `HeroSelectionPolicy`; **no such file exists**.
Hero item selection is currently **inline**, not extracted into a tested policy.
Extracting `HeroSelectionPolicy` (pure, tested) is a reasonable, low-risk future refactor that would mirror `HeroRotationPolicy`, but it is not required and is not part of this pass.

Already live: rotation, status chip, manual next.
Needs validation: on-device rotation cadence + focus stability capture (Epic 5).
Deferred: silent trailer auto-preview (Epic 4 — playback + perf + device validation). **Do not add trailers in this pass.**

---

## 9. Adaptive visual language / Liquid Glass

| Apple effect | Rivulet | Status |
| --- | --- | --- |
| Dynamic backdrop tint from poster colour | (none in main media views) | **Gap.** |
| Glass materials / blur overlays | `GlassRowStyle`, `ultraThinMaterial` (music detail, settings) | Partial — materials exist, not media-colour-aware. |
| Blurred artwork backgrounds | `HeroBackdropLayer` (static art) | Partial. |
| Media-colour-aware surfaces | (none — no dominant-colour extraction found) | **Gap.** |
| Overlay readability | Existing gradients/scrims on hero/detail | Live. |
| Card density | `ContentDesignTokens` (scales, spacing) | Live. |
| Consistent depth/shadow/focus | Native `.card` + tokens | Live. |

Mapping targets: `ContentDesignTokens`, `GlassRowStyle`, `DetailMetadataCascade`, hero/detail backgrounds, `Docs/DESIGN_GUIDE.md`.

Classification:

- **Epic 3 visual-system adoption:** an adaptive poster-colour tint behind detail/hero (dominant-colour extraction → tinted, heavily-blurred, low-opacity backdrop) is the highest-impact "feels like Apple TV" gap. Pure UI, Plex-art-powered, no provider/playback risk.
- **Future detail-page polish:** broader glass adoption across detail sections.
- **Performance risk:** colour extraction must be off the main thread, cached per item, and bounded — naive per-frame extraction will hurt the 60/120 Hz scroll budget. Reuse the existing image pipeline rather than decoding twice.
- **Accessibility / contrast risk:** any tinted backdrop must preserve text contrast under Increase Contrast / Reduce Transparency; gate behind those settings.

No visual changes in this pass.

---

## 10. Channels / brand hubs

Apple groups content by production house (Showtime, Paramount+, HBO) into branded landing pages.

Rivulet mapping options (data already present): Plex `studio` / network metadata, Plex collections, Plex labels, library sections.

Classification:

- A **possible future Epic 3/5 feature**, not part of current Epic 3 closure (it was not scoped into Epic 3).
- Significant **trade-dress / brand risk**: reproducing network corporate colours and logos invites IP problems and cuts against the "distinct app, no trade dress" guardrail. Any future version should use neutral Rivulet styling, not network brand kits, and must not present an "Apple TV+" hub.

Do not implement brand hubs now.

---

## 11. Tab structure

Current Rivulet navigation (sidebar `SidebarSection`): Search, Home, Library (per Plex library), Live TV (Channels + Guide), Settings — plus Discover and Music surfaces.

| Apple tab | Relevant to Rivulet? | Mapping |
| --- | --- | --- |
| Search | Yes | Plex global search (live). |
| Home | Yes | Hero + Continue Watching + hubs (live). |
| Library | Yes | Plex library sections (live). |
| Discover | Yes (Rivulet-specific) | TMDb-backed Discover (live). |
| Settings | Yes | Settings (live). |
| Apple TV+ tab | **No** | Reject — Apple branding. |
| Channels tab (non-owned aggregation) | **No** | Reject — partner aggregation. |

Rivulet's tab structure already aligns with the useful Apple tabs.
Do **not** restructure navigation (it was settled in Epic 2), and never add an Apple TV+ / partner-aggregation tab.

---

## 12. Contextual rows

| Apple row | Rivulet | Status |
| --- | --- | --- |
| More Like This | `recommendedRow` + `PersonalizedRecommendationService` + `relatedShowRatingKey` | Live, but via a **bespoke** recommendation service, not Plex related hubs. |
| Based on cast/director/genre | (partially via recs) | Partial. |
| Cast & Crew spotlight | `castCrewRow` (cast + directors, headshots, initials fallback) | Live (PR11). |
| Studio / network rows | (none) | Gap (tied to Channels, §10). |
| Recently watched context | Continue Watching | Live. |

Opportunity: Plex returns pre-calculated related content with `includeRelated=1` (`Hub='similar'`, `Hub='director'`).
Evaluating whether to source "More Like This" from Plex related hubs (cheaper, server-calculated, library-accurate) versus the current bespoke service is a reasonable **Epic 3 backlog** item — but it touches recommendation behaviour and should be a deliberate, tested slice, not folded into ADO-05.

Belongs in Epic 3 adoption: cast spotlight (done), rating/status polish.
Belongs in later backlog: Plex-related-hub sourcing, studio/network rows.

---

## 13. Trailers / extras

| Apple behaviour | Rivulet | Status |
| --- | --- | --- |
| Detail trailer playback | "Play Trailer" button → `loadAndPlayTrailer()` from Plex `Extras` (`extraType==1`/`subtype=="trailer"`); `MediaItemDetail.trailerURL` | **Live** (detail page). |
| Silent top-shelf auto-preview | (none) | Gap. |
| TMDb trailers | `TMDBMediaMapper` sets `trailerURL: nil` today | Not wired. |

Classification:

- **Epic 3 trailer presentation:** detail trailer playback already works; no new Epic 3 trailer work is required. (There is a `TODO(post-wave-1)` to stream the trailer directly via `trailerURL` without the extra Plex fetch — a small future optimisation, not this pass.)
- **Epic 4 playback behaviour:** hero silent auto-preview is a playback + performance + device-validation concern (autoplay risk, bandwidth, focus interaction). Defer.
- **Risks:** silent autoplay can surprise users, consume bandwidth, and complicate focus; requires explicit on-device validation before it ships.

Do not implement trailer auto-preview now.

---

## 14. Chapter navigation

This is **already implemented** and lives in the player (Epic 4 territory), not Epic 3.

- `PlexNetworkManager` already requests `includeChapters=1`.
- `UniversalPlayerViewModel` parses `metadata.Chapter`, fetches chapter thumbnails (bounded concurrency), and feeds the player chapter UI.

Classification: **Epic 4 only** — and largely done.
No chapter work belongs in Epic 3.
Epic 4 should *validate and polish* the existing chapter strip (thumbnail coverage, scrub interaction, glass styling), not rebuild it, and must respect the "no playback changes" constraint until Epic 4 is explicitly authorised.

---

## 15. Image caching / downscaling

| Concern | Rivulet | Status |
| --- | --- | --- |
| Server-side downscale | `/photo/:/transcode` (`PlexNetworkManager:1780`) resizes on the Plex server | Live — Apple-correct. |
| Client cache | `CachedAsyncImage` + `ImageCacheManager` | Live. |
| Top Shelf handoff | Local-file handoff in App Group (Epic 2 PR2), secret-free | Live. |
| Hero / landscape loading | Through the same cached pipeline | Live. |

Findings:

- **Safe improvements:** none critical. The Plex photo-transcode path already gives Apple-style server-side downscaling; verify call sites pass sensible width/height so the server actually downsizes (display-only check, not a rewrite).
- **Token risk:** Plex image URLs (including `/photo/:/transcode`) are **token-bearing** — this is existing, tracked debt (`KF-E0-002` / `DEBT-E0-002`), not introduced here. Any image-pipeline work must not widen token exposure (no token-bearing URLs into logs, the Top Shelf payload, or Sentry).
- **Performance:** the adaptive-tint idea (§9) must reuse already-decoded cached images rather than re-fetching/re-decoding.

Do not implement image changes unless a critical bug surfaces — none did in this audit.

---

## 16. Apple partner-only items to exclude

Must **not** implement or claim:

- Universal Search integration (no partner entitlement).
- Up Next integration *in the Apple TV app* (system-level, partner-only).
- An "Apple TV+" tab.
- The Apple Original flag / `isOriginal` premium layout.
- Apple ranking / editorial-placement claims ("#1 Show on Apple TV", "Trending", "Editors' Choice", "What to Watch").
- The official Coming Soon **feature** (Apple-Subscription-Video-partner-only, qualification-gated, feed-driven — confirmed live). Rivulet may show its *own* data-derived "Coming \<date\>" label; it must not present Apple's Coming Soon product.
- Transporter / Apple XML feed creation or validation.
- Partner entitlements of any kind.
- Apple editorial placement / curation.

---

## 17. Epic mapping

| Idea | Disposition |
| --- | --- |
| Content status labels on hero + detail | **Already complete** (ADO-04). |
| Technical display badges on landscape cards | **Already complete**. |
| Continue Watching prominence + VoiceOver | **Already complete** (Epic 2). |
| Cast & crew spotlight | **Already complete** (PR11). |
| Trailer playback on detail | **Already complete**. |
| Chapter navigation in player | **Already complete** (player). |
| Hero auto-rotation + status chip | **Already complete**. |
| Episode-card status labels | **Epic 3 adoption** (ADO-05). |
| "Another Season Is Coming" (renewed, no date) | **Epic 3 adoption** (model/test). |
| Rating-badge styling (rounded badge) | **Epic 3 adoption** (ADO-06 candidate). |
| Adaptive poster-colour tint / Liquid Glass | **Epic 3 adoption** (ADO-06 candidate). |
| Badge adoption on more card types / detail | **Epic 3 adoption**. |
| Plex `includeRelated` "More Like This" sourcing | **Future backlog** (deliberate slice). |
| Playback-capability badges (true DV/Atmos delivery) | **Epic 4 playback**. |
| Hero silent trailer auto-preview | **Epic 4 playback**. |
| Chapter-nav polish/validation | **Epic 4 playback**. |
| On-device a11y + perf capture for the above | **Epic 5 release validation**. |
| Channels / brand hubs | **Future backlog** (trade-dress risk). |
| Apple branding / ranking / TV+ / Universal Search / feed | **Out of scope** (§16). |

---

## 18. ADO-05 impact

**Should ADO-05 still be episode-card status labels?** — Yes.
It is the smallest, fully **Plex-backed** slice (no TMDb, no playback), it completes the Content Status Label System across its last unused placement (`episodeCard`), and it carries the lowest regression risk.
The data is already present: `seasonFinale` from `index == leafCount`, `recentlyAdded` from `addedAt`, `episodeAvailableToday` / `newEpisode` from `originallyAvailableAt`.

**Should ADO-05 become broader detail-page status/metadata polish instead?** — No.
The detail page already adopts the status chip (ADO-04). Broader polish (adaptive tint, rating-badge styling) is real and valuable but is visual-system work better scoped as ADO-06, separate from the label-system completion.

**Should ADO-05 include content rating / technical badges?** — No (keep it focused).
Technical display badges already exist on landscape cards; rating-badge styling is presentation polish that should not ride along with episode-card label adoption. Capability badges are Epic 4.

**Safe now (Epic 3, no playback / no Epic 1 boundary / no TMDb endpoint change):**

- Episode-card status labels (ADO-05) — Plex-only.
- "Another Season Is Coming" renewed-no-date case — pure model + classify rule + tests. The brief permits pure documentation/model clarification, so this **may** be folded into ADO-05 as a model addition; otherwise it is a trivial standalone slice.
- Rating-badge styling and adaptive tint — safe but better as ADO-06.

**Require Epic 4:** playback-capability badges, hero silent trailer auto-preview, chapter-nav polish.

Recommendation: **ADO-05 = episode-card status labels**, optionally including the renewed-no-date model case (documentation/model-only). No implementation in this audit pass.

**Update (2026-06-01):** ADO-05 shipped as recommended — episode cards now surface `seasonFinale` / `episodeAvailableToday` / `newEpisode` from Plex-only data (pure `EpisodeCardPresentation.episodeStatusLabel`, placement-gated to `episodeCard`), with specials/missing-data guards, accessibility folded into the play control's combined label, and tests. No TMDb/provider/playback change. The renewed-no-date case was *not* taken (it remains a hero/detail concept). The next visual-system items (adaptive tint, rounded rating badge) stay queued as ADO-06 / `DEBT-E3-APPLEREF-001`.

---

## 19. Debt updates

Proposed updates (not applied to the register in this pass beyond this audit doc; apply alongside the relevant slice):

- **`DEBT-E3-ADO03-001`** — keep open. Refine the open list to: (a) "Another Season Is Coming" renewed-no-date case **[model/test, ready]**; (b) episode-card status labels **[= ADO-05]**; (c) on-device visual validation of hero + detail labels. Do **not** close — (b) and (c) remain.
- **`DEBT-E3-PR7-001`** — keep open, note that **technical-badge mapping is now adopted on landscape cards** (no longer fully outstanding); remaining: broader row migration to landscape/badge cards, badge adoption on detail + other card types, and on-device visual confirmation.
- **New: `DEBT-E3-APPLEREF-001` (proposed, Minor)** — Apple-reference visual-system adoption: adaptive poster-colour backdrop tint and Apple-style rounded rating badge. Plex-art / Plex-rating powered, pure UI. Owner: Epic 3. Risk: perf + contrast (§9). Candidate ADO-06.
- **New: `DEBT-E4-APPLEREF-001` (proposed, Minor)** — Epic-4-only playback-reference items: playback-capability badges (route-verified DV/Atmos), hero silent trailer auto-preview, chapter-nav polish/validation. Owner: Epic 4. Must respect "no playback changes until Epic 4 authorised".

No debt is falsely closed.
Existing `KF-E0-002` (token-bearing image URLs) is referenced, not resolved, by this audit.

---

## 20. Final recommendation

**Recommended next slice:** **ADO-05 — episode-card status labels** (Plex-only), optionally folding in the "Another Season Is Coming" renewed-no-date model case (pure model/test).

**Why it is next:** it is the smallest remaining slice, fully data-backed by Plex with no TMDb or playback dependency, it completes the Content Status Label System across its final placement (`episodeCard`), and it has the lowest regression surface — consistent with small, focused, verifiable PRs.

**What should not be done yet:**

- Adaptive tint / rating-badge styling (defer to ADO-06 — valuable but visual-system scope).
- Plex `includeRelated` "More Like This" sourcing (deliberate future slice).
- Anything Epic 4: playback-capability badges, hero silent preview, chapter polish.
- Channels / brand hubs (future, trade-dress risk).
- Every §16 partner-only / Apple-branding item (permanent reject).

**Can Epic 3 close after current adoption?**
Yes — after ADO-05 (episode-card labels) lands and the on-device visual/accessibility capture for the status-label surfaces is recorded.
The adaptive-tint and rating-badge polish (ADO-06 / `DEBT-E3-APPLEREF-001`) are quality enhancements, not closure blockers, and can be carried as accepted debt.

**Can Epic 4 begin?**
Not yet.
Epic 4 (playback excellence) should begin only after Epic 3 closes and only with explicit authorisation, per the standing constraint that playback must not be touched until then.

---

*This document is a benchmark audit. Rivulet is a distinct Plex/TMDb-backed tvOS app and is not an Apple TV partner application. No Apple branding, trade dress, ranking claims, private APIs, or partner-feed behaviour are adopted.*
