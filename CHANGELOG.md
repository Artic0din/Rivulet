# Changelog

## [Unreleased]

### Changed

- Epic 3 PR3: the row preview now respects the system Reduce Motion setting — poster→preview, paging, expand, and collapse transitions apply instantly (no animation) without losing the destination, while full motion is unchanged otherwise. Preview exit and focus return-to-poster behavior is now covered by tests.
- Epic 2 PR5: Continue Watching is now pinned as the most prominent Home content row, and its cards expose a full VoiceOver description (title, episode, time remaining, progress).
- Epic 2 PR4: Home is now hero-first — a large cinematic hero leads the Home screen by default, favouring Continue Watching, then featured and recently added content, with Play / More Info actions. (Can still be turned off in settings.)

### Security

- Epic 2 PR7: Home error messages are now sanitized before display — a failed request's technical description (which can contain a token-bearing URL) can no longer appear in on-screen copy. Users see calm, plain-language errors; clean messages like "the connection appears to be offline" are preserved.
- Epic 2 PR2: Top Shelf no longer shares Plex token-bearing image URLs with the system extension. Artwork is handed off as local files in the App Group; the extension reads local files only. Top Shelf items and deep links are unchanged.

### Internal (no user-facing change)

- Epic 3 PR6: added the Content Presentation System policy layer — a centralized, tested `ContentPresentationStyle` model plus pure policies for title/artwork fallback, runtime, content rating, technical-badge selection (resolution → video → audio), and the canonical metadata hierarchy. Foundation for the content card modes; no visual change yet.
- Epic 3 PR5: Discover now shows a calm loading and empty state instead of a blank page when no recommendations have loaded yet. Watchlist feedback is unchanged.
- Epic 3 PR4: detail-page hero metadata now renders in a deterministic, tested order (type → genres → year · duration) via `DetailMetadataCascade`. Behavior-identical; ordering is no longer scattered inline. No visual change.
- Epic 3 PR2: introduced a canonical content design-token layer (`ContentDesignTokens`) over `ScaledDimensions` and refactored `GlassRowStyle` to consume it. Behavior-identical (token values equal the prior literals, pinned by tests); establishes one source of truth for content focus opacities, scales, motion, depth, and the metadata type ramp. No visual change.
- Epic 3 PR1: Apple TV Content Experience decomposition + content-surface baseline audit (`Docs/modernization/epic-3/epic-3-decomposition.md`). Planning only; no behavior change.
- Epic 2 closed (with accepted debt): hero-first Home, prominent Continue Watching, deterministic navigation and focus, normalised/sanitized loading-empty-error states, and secure Top Shelf. Full test suite green (461 passed). On-device accessibility and numeric performance capture remain as pre-ship tasks. See `Docs/modernization/epic-2/epic-2-closure-report.md`.
- Epic 2 PR6: top-level navigation rules extracted into a deterministic, unit-tested `SidebarNavigationPolicy` (tab-change blocking during nested navigation, profile-switcher routing, and Settings/Discover fallback to Home). Behavior is unchanged; navigation is now provably deterministic. `SidebarTab` is now `nonisolated`, removing a main-actor-isolation warning. No visual change.
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
