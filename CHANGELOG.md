# Changelog

## [Unreleased]

### Security

- Epic 2 PR2: Top Shelf no longer shares Plex token-bearing image URLs with the system extension. Artwork is handed off as local files in the App Group; the extension reads local files only. Top Shelf items and deep links are unchanged.

### Internal (no user-facing change)

- Epic 2 PR3: deterministic, stale-safe Home focus restoration (`FocusRestorationPolicy` + hardened `FocusMemory`); focus is no longer stranded on items removed by a refresh. No visual change.
- Epic 2 PR1: shared home render-state model (`RenderState`/`RenderStateResolver`) and reusable `ContentStateView` surface replacing inline Home loading/empty/error views (visually identical).
- Epic 2 PR1: first-party `os_signpost` performance harness (`HomePerformanceTracer`) for launch→home, render-state, and hero-preparation timings (Epic 0 PERF budgets).

## 1.0.0 (Build 48)

- Added Discover + Watchlist tabs
- Added Music browsing
- Added pre-play audio and subtitle track pickers
- Added "Resume or Restart Prompt" setting (off by default)
- Bare touchpad tap surfaces the timeline overlay
- Fixed focus on player error screens
- Auto-transcodes codecs Apple TV can't decode (MPEG-2, VC-1, VP9, AV1)
- Fixed freeze when resuming after a paused scrub
- Fixed audio flutter on AAC, FLAC, and PCM tracks
- Fixed 401s on multi-server Plex accounts
- Each install gets its own Plex Dashboard identity

Thanks to @rrgomes for PR contributions in this release.

## 1.0.0 (Build 43)

- Refined the GUI to be more Apple TV+ esque
- Removed MPVKit. Defaulting to AVPlayer while I continue working on custom player (sorry, this means direct stream for now)
