# ADO-01 — EpisodeContentCard Live Adoption

Date: 2026-06-01
Owner: Epic 3 owner
Branch: `codex/epic-2-pr4-canonical-hero`
Status: Complete — with an important honesty correction (read §Outcome).

## 1. Current detail episode rendering (audit)

Episodes render in `MediaDetailView` via the **`EpisodeCard`** struct
(`MediaDetailView.swift:3268`), used at the unified all-seasons list (:1819) and
the per-season list (:1895). `EpisodeCard` is already an Apple-TV-style landscape
episode card:

- Landscape still (`episode.artwork.thumbnail`), rounded 16, `clipped`.
- "EPISODE n" label (uppercased), bold title, 3-line synopsis.
- Duration badge overlay, watch-progress bar, `WatchedCornerTag`.
- **Two focusable buttons**: thumbnail → `onPlay`; description → `onShowInfo`
  (opens episode detail). `prefersDefaultFocus` on the thumbnail.
- Spoiler blur (`hideSpoilersForUnwatched`), `mediaItemContextMenu`, whole-card
  focus scale, `EpisodeFocusModifier` for focus restoration.

Selection/play/navigation/watch-state all flow through existing closures
(`onPlay`, `onShowInfo`, context menu) and the Epic 1 provider/watch-state path —
unchanged.

## 2. Outcome (honest correction)

The pre-existing production `EpisodeCard` is **richer** than the standalone
`EpisodeContentCard` I built in E3-PR10 (which has a single button, no play/info
split, no context menu, no spoiler blur). **Swapping the simpler view in would
regress behaviour.** Per the no-regression rule, that is the wrong move.

So ADO-01 makes the *tested presentation logic* LIVE in the production card,
rather than shipping the weaker view:

- `EpisodeCard.episodeLabel` now sources the non-prefix label from
  `EpisodeCardPresentation.episodeLabel(index:)` (behaviour-identical to the
  prior "Episode n" → uppercased "EPISODE n").
- The thumbnail **play control now exposes a combined VoiceOver label** via
  `EpisodeCardPresentation.accessibilityLabel(episodeLabel:title:runtime:
  isWatched:progress:)` ("Episode 13, Be Still My Heart, 40m[, Watched / n
  percent watched]") plus a "Plays this episode" hint — a real, visible (with
  VoiceOver) accessibility improvement in the live detail screen.

**`EpisodeCardPresentation` is therefore now LIVE** (used by the production
episode card in a real user-facing flow). The standalone `EpisodeContentCard`
*view* remains unused and is **superseded** by the richer `EpisodeCard`.

### Recommendation
Retire `EpisodeContentCard` (and converge any unique styling into `EpisodeCard`)
in a small follow-up, OR invest in making `EpisodeContentCard` feature-complete
(play/info split, context menu, spoiler blur) to replace `EpisodeCard` — a larger
redesign. Until then, the `EpisodeContentCard` *view* stays BUILT-BUT-UNUSED and
that portion of `DEBT-E3-PR7-001` stays open. This is flagged rather than hidden.

## 3. Focus behaviour
Unchanged: the two-button focus scope, `prefersDefaultFocus`, whole-card scale,
and `EpisodeFocusModifier` restoration are untouched. `FocusRestorationPolicyTests`
(10) and `FocusMemoryTests` (6) pass.

## 4. Accessibility
The play control now reads a complete episode summary (number, title, runtime,
watched/progress state) — previously VoiceOver read fragmented overlay text. The
info button and watched tag labels are unchanged. On-device VoiceOver capture
still pending (`DEBT-E0-007`).

## 5. Schedule labels
**Deferred to ADO-03** per the slice directive. Episode-card adoption needs no
schedule label, and surfacing one safely needs a hero/detail consumer + real
air-date data to verify. `ScheduleLabelPolicy` stays BUILT-BUT-UNUSED.

## 6. Validation
- `git diff --check` clean.
- `xcodebuild build` exit 0, 0 errors.
- Tests pass: `EpisodeCardPresentationTests` (9, incl. resolved-values overload),
  `ScheduleLabelPolicyTests` (9), `FocusRestorationPolicyTests` (10),
  `FocusMemoryTests` (6), `PlexProviderBoundaryTests` → ** TEST SUCCEEDED **.

## 7. Debt
Reduces the **episode-presentation** portion of `DEBT-E3-PR7-001` (the episode
presentation logic is now live in production). Keeps open: the `EpisodeContentCard`
view (unused/superseded), `LandscapeContentCard`, `ContentPresentationPolicy`,
`ScheduleLabelPolicy`.

## 8. Simulator validation instructions
1. Build/run Rivulet on the Apple TV simulator, sign in to Plex.
2. Open any TV **show → episode detail** (a show with episodes).
3. The episode cards in the season list are the production `EpisodeCard` (now
   sourcing their "EPISODE n" label from the tested policy).
4. Enable **Settings → Accessibility → VoiceOver** and focus an episode's
   artwork: it should announce "Episode N, <title>, <runtime>[, Watched / N
   percent watched], Plays this episode."
5. Confirm play (click artwork) and info (click description) still work, and
   left/right focus moves between cards landing on the artwork.

> Note: the visible *card layout* is unchanged (it was already Apple-TV-style);
> the live change is the policy-sourced label + the VoiceOver summary.
