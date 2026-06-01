# E3-PR10 — Episode Cards + Schedule/Air-Date Labels

Date: 2026-06-01
Owner: Epic 3 owner
Workstream: Content Presentation System (Product Direction #2)
Branch: `codex/epic-2-pr4-canonical-hero`

## Objective

Add Apple-TV-style episode cards and contextual schedule/air-date labels, driven
by pure tested policies over existing Plex data — no playback, watch-state, or
external-provider change.

## Change

- `ScheduleLabelPolicy` (pure, tested): resolves `ScheduleLabel`
  (New / Recently Added / Season Finale / Continue Watching) deterministically,
  most-specific-first, from days-since-aired, days-since-added, episode index vs
  season count, and in-progress. Returns nil when data is insufficient — never a
  misleading label. Cadence labels ("New Episode Every Wednesday") are omitted
  because Plex does not expose release cadence. Helpers parse Plex
  `originallyAvailableAt` and compute whole-days against a passed reference date
  (no `Date.now()`, fully deterministic).
- `EpisodeCardPresentation` (pure, tested): `EpisodeCardModel` + "EPISODE n"
  label + runtime (via `RuntimeFormatter`) + progress (only when partially
  watched) + combined VoiceOver label (episode, title, runtime, state).
- `EpisodeContentCard` (additive view): landscape still, "EPISODE n" label,
  title, synopsis, runtime row, watched tag / progress bar, readable gradient,
  Reduce-Motion-gated focus emphasis, combined VoiceOver label, no focus-time
  fetch.

## Data source

All from the existing Plex model (`index`, `parentIndex`, `title`, `summary`,
`duration`, `viewOffset`, `originallyAvailableAt`, `addedAt`, `leafCount`). No
new provider; TVDb/TMDb remain optional future enhancements, not added here.

## Deferred with debt

`EpisodeContentCard` is additive — not yet wired into the detail seasons/episodes
list (which renders its own episode rows). Production adoption + on-device
validation join `DEBT-E3-PR7-001` (card production adoption). The pure policies
(`ScheduleLabelPolicy`, `EpisodeCardPresentation`) are ready for immediate use by
hero/detail surfaces.

## Validation

- `xcodebuild build` exit 0, 0 errors.
- `ScheduleLabelPolicyTests` (9) + `EpisodeCardPresentationTests` (6) pass →
  ** TEST SUCCEEDED **.
- `git diff --check` clean. No playback / watch-state / Epic 1 / provider change.
