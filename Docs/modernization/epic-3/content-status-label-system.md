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

### TMDb (modelled today)
`TMDBListItem`: `release_date`, `first_air_date`. `TMDBItemDetail`:
`release_date`, `first_air_date`, `runtime`, `genres`, `cast`. **That is all.**

Missing (NOT fetched/modelled) — the future-facing gap:
- `status` (e.g. Returning Series / Ended / In Production)
- `next_episode_to_air` (date + season/episode)
- `last_episode_to_air`
- `in_production`
- per-season `air_date`, per-episode `air_date`
- `number_of_seasons` / `number_of_episodes`

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

## 5. Future metadata requirements (TMDb expansion)

To light up the future-facing labels, extend `TMDBItemDetail` (and the
`/tv/{id}` / `/movie/{id}` fetch in `TMDBClient`) with:
- `status: String`
- `in_production: Bool`
- `next_episode_to_air: { air_date, season_number, episode_number }`
- `last_episode_to_air: { air_date }`
- `number_of_seasons`, `seasons[].air_date`

No new endpoint is required — these are fields on the existing detail endpoints,
so it is a model/decoding expansion, not a new provider call pattern. Tracked as
**DEBT-E3-ADO03-001**.

## 6. Live adoption status

**Not adopted in UI this slice (Option A).** Recommended adoption once TMDb
fields exist:
1. Hero — premieres/returns/newSeason/comingSoon/allEpisodesAvailable (the
   high-value editorial line).
2. Episode cards — seasonFinale (already data-backed via Plex; a clean, low-risk
   first live use even before TMDb).

The model + placement already encode (2) as data-backed today, so a follow-up can
ship episode-card `seasonFinale` immediately without touching this architecture.
