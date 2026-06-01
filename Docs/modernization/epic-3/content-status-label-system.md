# Content Status Label System (ADO-03)

Date: 2026-06-01
Type: Architecture + model + placement rules + tests (Option A — no live UI
adoption this slice). Supersedes the narrow `ScheduleLabelPolicy`.

## Decision

**Option A.** Build a future-proof Content Status Label model, classifier, and
placement rules with full unit tests; **do not** force live UI adoption. The
editorially valuable labels (the reason the hero would carry status messaging)
are future-facing — "Premieres Friday", "Returns 12 Sep", "New Season Aug", "New
Episode Every Friday" — and those require TMDb fields the app does not model
today. Shipping only the past-facing labels we *can* back now ("Recently Added"
on the hero) would be exactly the noisy generic chip the brief warns against.
The architecture is wired so that when the TMDb fields land, the labels light up
with no second system and no re-architecture.

## 1. Data / model audit

### Plex (already fetched — hero items, detail, episodes)
| Field | Meaning | Status-label use |
| --- | --- | --- |
| `originallyAvailableAt` ("yyyy-MM-dd") | air/release date (past) | New Episode / today / season air (past only) |
| `addedAt` (epoch) | library add time | Recently Added |
| `index` / `parentIndex` | episode / season number | Season Finale (`index == leafCount`) |
| `leafCount` / `viewedLeafCount` | total / watched episodes | Season Finale denominator; progress |
| `childCount` | season count (shows) | (future: season math) |
| `viewOffset` / view counts | progress / watched | (progress UI already exists) |

**Plex cannot express the future.** No "ended"/"in production"/"next air date"
field exists, so future-facing labels and a trustworthy "All Episodes Available"
are not derivable from Plex alone. `seriesIsComplete` is left nil today
(conservative — never guessed).

### TMDb (CORRECTED 2026-06-01 against the TMDb OpenAPI spec)

Earlier this doc implied the future-facing fields were unavailable / a large lift.
That was wrong. Verified against `tmdb-api.json`:

- **`GET /3/tv/{series_id}`** (the standard TV *detail* endpoint) returns, in its
  base payload: `status`, `in_production`, `first_air_date`, `last_air_date`,
  `next_episode_to_air` (incl. `air_date`, `season_number`, `episode_number`),
  `last_episode_to_air`, `number_of_seasons`, `number_of_episodes`, `type`,
  `episode_run_time`, `networks`, and `seasons[]` with
  `{ air_date, episode_count, season_number }`.
- **`GET /3/movie/{movie_id}`** returns `status`, `release_date`, `runtime`.
- **`GET /3/tv/{series_id}/season/{n}`** returns `episodes[]` with `air_date`,
  `episode_number`, `season_number` (per-episode dates, if ever needed).

So **every future-facing label is backed by TMDb's standard detail endpoints** —
no new endpoint, no `append_to_response`, no extra round-trip.

**What the app models today (the real, smaller gap):** the app already fetches a
per-item detail via its proxy (`tmdb/details/{id}` → `TMDBDiscoverService.fetchDetail`)
and decodes it into `TMDBItemDetail`, which currently keeps only `title`,
`overview`, poster/backdrop, `release_date`/`first_air_date`, `runtime`, `genres`,
`cast`. The future-facing fields are simply **not decoded** (and `fetchDetail`
re-constructs `TMDBItemDetail` field-by-field, so new fields must be added there
too). The proxy returns TMDb's detail JSON, so — assuming it is a passthrough —
the fields are already in the response body and the work is **decode/model-only**.

### Implementable now vs. needs TMDb
| Label | Backed now? | Source |
| --- | --- | --- |
| `seasonFinale` | ✅ | Plex `index == leafCount` |
| `episodeAvailableToday` | ✅ | Plex `originallyAvailableAt == today` |
| `newEpisode` | ✅ | Plex `originallyAvailableAt` within 14d |
| `recentlyAdded` | ✅ | Plex `addedAt` within 30d |
| `allEpisodesAvailable` | ⚠️ only if a trustworthy "ended" signal exists → **needs TMDb `status`** |
| `premieres(date)` | ❌ | TMDb `next_episode_to_air` / release date (future) |
| `returns(date)` | ❌ | TMDb `status=Returning` + `next_episode_to_air` |
| `newSeason(date)` | ❌ | TMDb season `air_date` (future) |
| `newEpisodeWeekly(weekday)` | ❌ | TMDb recent episode `air_date` cadence inference |
| `comingSoon(date)` | ❌ | TMDb release/first-air date (future) |

## 2. Model

`Rivulet/Views/Components/ContentStatusLabel.swift`:
- `ContentStatusLabel` — enum of all cases above; `displayText` (plain-language,
  no copied trade dress); `isFutureFacing`.
- `ContentStatusInput` — `kind` + current Plex inputs + **optional** future TMDb
  inputs (nil today; populating them later turns the labels on).
- `ContentStatusPolicy.classify(_:reference:)` — deterministic precedence:
  future events (only if their date is still ahead of `reference`) → season
  finale → episode-today → new episode → all-episodes → recently-added → nil.
  Pure, no `Date.now()` (caller supplies the reference date).
- Date helpers: `parseAirDate`, `daysAgo`, `addedDate(fromEpoch:)`.

Truthfulness guarantees: a future label never fires from a past date; a negative
"aired days ago" (future air) never reads as new/today; missing data → nil.

## 3. Placement rules

`ContentStatusPlacement.allows(_:on:)` over `ContentStatusSurface`:
| Surface | Allowed labels |
| --- | --- |
| **hero** (primary) | editorial/show-level: premieres, returns, newSeason, weekly, comingSoon, allEpisodesAvailable, recentlyAdded |
| **detail** (secondary) | same as hero |
| **episodeCard** (conditional) | per-episode only: seasonFinale, episodeAvailableToday, newEpisode |
| **shelf** (rare) | none — the row title already gives context; per-card chips read as noise |

Hero hierarchy when adopted: **Status label → Title → Metadata → Synopsis →
Actions** (placement only; no hero redesign in this slice).

## 4. Apple TV reference review (conceptual only)

From the supplied screenshots — analysed for *category*, not copied:
- **Emulate conceptually:** one short status line answering "why now?", placed
  above the title; future-facing and editorial ("Premieres…", "New Season…",
  "All Episodes…"); shown sparingly (hero/detail), never on every tile.
- **Do NOT copy:** exact wording, Apple's chip styling/trade dress, layout, or
  per-app availability phrasing. Our `displayText` uses generic domain phrases.
- **Why valuable:** it converts a static poster wall into a reason-to-watch — the
  past-facing tag alone ("Recently Added") does not deliver that, which is why
  the TMDb expansion (future dates) is the real unlock.

## 5. Future metadata requirements (TMDb decode expansion — CORRECTED)

To light up the future-facing labels, expand decoding of the **already-fetched**
`tmdb/details/{id}` payload (no new endpoint, no extra round-trip):

1. Add to `TMDBItemDetail` (+ `CodingKeys`, both inits, and the field-by-field
   rebuild in `TMDBDiscoverService.fetchDetail`):
   - `status: String?`, `inProduction: Bool?`
   - `firstAirDate` (already a coding key; surface it), `lastAirDate: String?`
   - `nextEpisodeToAir: { airDate, seasonNumber, episodeNumber }?`
   - `lastEpisodeToAir: { airDate }?`
   - `numberOfSeasons: Int?`, `seasons: [{ airDate, episodeCount, seasonNumber }]?`
2. Map them through `TMDBMediaMapper.detail` → `MediaItemDetail` (new optional
   fields) so the hero/detail view can build a `ContentStatusInput`:
   - `newSeason(date)` ← future-dated `seasons[].air_date`
   - `returns(date)` / `premieres(date)` ← `next_episode_to_air.air_date` (+ `status`)
   - `allEpisodesAvailable` ← `status == "Ended"` / `in_production == false`
   - `comingSoon(date)` ← movie `release_date` / show `first_air_date` in the future
3. **Verify the proxy passes these fields through.** The app reads
   `tmdb/details/{id}` from a backend proxy; if that proxy projects a subset, add
   the fields to its projection. (If it is a raw passthrough, step 1 alone
   suffices.) This is the only possible non-app touch and is small.

Effort: **low–medium, decode/model-only.** Tracked as **DEBT-E3-ADO03-001**.

## 6. Live adoption status

### ADO-04 update (2026-06-01) — Hero adoption LIVE (data-contingent)

The TMDb status fields are now **decoded** (`TMDBStatusDetail`) from the same
`tmdb/details/{id}` payload the app already fetches, bridged to `ContentStatusInput`
(`TMDBContentStatus`), and surfaced on the **Home hero** above the title
(`HeroSlideContent.statusChip`). Resolution is per displayed hero item, cached on
disk, off the main thread, and rotation-stable (keyed by ratingKey). The chip
appears only when `ContentStatusPolicy` returns a hero-eligible label and hides
otherwise — no chip on missing/stale data, no "Recently Added" noise (past-facing
Plex inputs are deliberately not fed to the hero).

Reference screenshots (Apple TV) reviewed for ADO-04 map to our labels:
| Apple TV reference | Our label |
| --- | --- |
| "New Season 5 Aug" | `newSeason(date)` → "New Season \<MMM yyyy\>" |
| "All Episodes Now Available" | `allEpisodesAvailable` → "All Episodes Available" |
| "New Episode Every Friday" | `newEpisodeWeekly(weekday)` |
| "Premieres Friday" / "Returns 12 Sep" | `premieres(date)` / `returns(date)` |
| **"#1 Show on Apple TV"** | **NOT modelled — Apple ranking/branding claim, intentionally excluded** |
| "Another Season Is Coming" (renewed, no date) | not yet modelled — future `renewed` case (no date) — candidate follow-up |

**Proxy passthrough — CONFIRMED (live probe, 2026-06-01).** I queried the
backend proxy directly (`https://tmdb-proxy.baingurley.workers.dev/tmdb/details/{id}`):
- Ted Lasso (`97546`, tv): `status="Returning Series"`, `in_production=true`,
  `next_episode_to_air.air_date="2026-08-04"`, `episode_number=1`, `season 4` →
  maps to **New Season Aug 2026** (matches the Apple "New Season 5 Aug" reference).
- Breaking Bad (`1396`, tv): `status="Ended"`, `in_production=false`,
  `next_episode_to_air=null` → **All Episodes Available**.
- Dune: Part Two (`693134`, movie): `status="Released"`, past `release_date` →
  **no label** (correct).

So the proxy is a full passthrough — the status fields arrive and the labels are
data-backed end to end. The remaining real caveats are: (a) a hero item must
carry a `tmdbId` at render (Plex-side; hub items without a Guid array resolve to
no label); (b) on-device VISUAL confirmation of the rendered chip. Both tracked
in `DEBT-E3-ADO03-001`.

`newEpisodeWeekly` is modelled but not yet emitted (weekly-cadence inference from
episode air dates is deferred — not faked). "Another Season Is Coming" (renewed
without a date) is a candidate future case.

### Recommended further adoption
1. Hero — premieres/returns/newSeason/comingSoon/allEpisodesAvailable (the
   high-value editorial line).
2. Episode cards — seasonFinale (already data-backed via Plex; a clean, low-risk
   first live use even before TMDb).

The model + placement already encode (2) as data-backed today, so a follow-up can
ship episode-card `seasonFinale` immediately without touching this architecture.
