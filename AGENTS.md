# Rivulet — Agent Context

Rivulet is a tvOS media client for Plex and IPTV. SwiftUI throughout.
Two video players: **RPlayer** (custom FFmpeg → `AVSampleBufferDisplayLayer` pipeline, full HDR/Dolby Vision) and **AVPlayer** (`NativePlayerViewController`) for natively-playable routes. `ContentRouter.plan(...)` picks the route per item.

This is the portable, tool-agnostic rule set (Codex, Gemini, and other agents read `AGENTS.md`; the Claude agent reads `CLAUDE.md`, which mirrors this plus Claude-specific skill routing). Keep the two in sync when changing shared rules.

## Quick reference

- **Platform:** tvOS 26.2+ (Apple TV)
- **Language:** Swift, language mode 5 (`SWIFT_VERSION = 5.0`). Write Swift-6-ready code: `Sendable`-correct types, explicit actor isolation, no new data races — Swift 6 migration is the intent.
- **UI:** SwiftUI; Liquid Glass aesthetic (tvOS 26)
- **Tests:** `RivuletTests/` — mixed XCTest + Swift Testing. New tests use Swift Testing (`import Testing`); migrate XCTest opportunistically.
- **Errors:** Sentry (`RivuletApp.swift`).

## Project structure

```
Rivulet/
├── Models/           # Plex API models; SwiftData persistents (Channel, EPGProgram, PlexServer)
├── Services/
│   ├── Plex/         # PlexNetworkManager, PlexAuthManager, PlexDataStore
│   │   └── Playback/ # RPlayer: Pipeline/, FFmpeg/, Dovi/, Subtitles/, Remux/
│   ├── LiveTV/       # PlexLiveTVProvider, IPTVProvider, LiveTVDataStore
│   ├── IPTV/         # M3UParser, XMLTVParser, DispatcharrService
│   ├── Cache/        # CacheManager, ImageCacheManager
│   └── Focus/        # FocusMemory (section focus restoration)
├── Views/
│   ├── Player/       # UniversalPlayerView/-ViewModel, NativePlayerViewController, overlays
│   ├── Media/        # MediaDetailView, PlexHomeView, hubs, hero, carousels
│   ├── Music/  Discover/  LiveTV/  Settings/  Components/  TVNavigation/  Root/
└── Docs/             # adr/ (committed); other Docs/* are local-only (gitignored)
```

Key entry points: `Services/Plex/Playback/RivuletPlayer.swift`, `Pipeline/ContentRouter.swift`, `Pipeline/DirectPlayPipeline.swift`, `Views/Player/UniversalPlayerViewModel.swift`, `Services/Plex/PlexNetworkManager.swift`.

## Video players

`ContentRouter.plan(...)` returns `PlaybackPlan { primary, fallbacks }`. Route cases: `.avPlayerDirect`, `.localRemux`, `.hls`, plus the RPlayer DirectPlay path.

- **AVPlayer routes** (`NativePlayerViewController`): `.avPlayerDirect` (natively-playable MP4 + native audio, no DV P7), `.localRemux` (MKV / DV P7 / DTS / TrueHD via `LocalRemuxServer` over HLS on localhost). The `useApplePlayer` UserDefault biases toward these.
- **RPlayer DirectPlay**: FFmpeg demux (`FFmpegDemuxer`, with `URLSessionAVIOSource` for http(s) — parallel ranged GETs, required for 4K throughput on tvOS) → VideoToolbox video + passthrough/`FFmpegAudioDecoder` audio → `SampleBufferRenderer` (`AVSampleBufferDisplayLayer` + `AVSampleBufferAudioRenderer` + `AVSampleBufferRenderSynchronizer`, the A/V clock). `HLSPipeline` is the fallback after a direct-play crash.
- **Codec routing:** H.264/H.265/DV P5/P8.1 → VideoToolbox. DV P7/P8.6 → `HEVCNALParser` extracts RPU → `DoviProfileConverter`/`LibdoviWrapper` rewrites to P8.1 → VideoToolbox. AAC/AC3/EAC3 → passthrough. TrueHD/DTS/PCM/FLAC → `FFmpegAudioDecoder` → 32-bit float PCM. SRT/ASS → text overlay; PGS/DVB → `FFmpegSubtitleDecoder` bitmap (PGS uses `end_display_time = UInt32.max` as "until next cue").
- **Measured timing constants — do NOT change without re-measuring:** read-loop throttle ~0.8 s (matches `AVSampleBufferDisplayLayer`'s ~1 s forward window for 4K HEVC); preroll ~450 ms DV / ~200 ms otherwise; AirPlay startup buffer 1.0 s; seeks within 0.5 s deduplicated. A/V clock is the synchronizer's — never add explicit video delay.

A fuller deep reference (`Docs/RIVULET_PLAYER.md`) is kept **local-only / gitignored** as an internal dev doc; it is not in fresh clones, so do not depend on it.

## tvOS focus — house patterns

Standard SwiftUI focus primitives only; no custom focus scope manager.

- **`fullScreenCover`** for focus-isolated overlays. Transparent overlays add `.presentationBackground(.clear)`.
- Initial focus: `@FocusState` set in `.onAppear`. Dismissal: `.onExitCommand`.
- **`FocusMemory`** restores focus within scrollable sections: `.focusSection()` + `.remembersFocus(key:focusedId:)`.
- `TabView` with `sidebarAdaptable` for system-managed sidebar/content focus.

## UI conventions

- Glass row styling is canonical (`Views/Components/GlassRowStyle.swift`): focused `white.opacity(0.18)` fill / `0.25` border, unfocused `0.08`/`0.08`; scale `1.02`; spring `(response: 0.3, dampingFraction: 0.7)`.
- Remote images: always `CachedAsyncImage` (never bare `AsyncImage`).
- Settings rows are **title-only** (`SettingsComponents.swift`); descriptive copy lives in the left-side description panel driven by `SettingsDescriptors.swift`, keyed by `focusedSettingId`.
- Design philosophy: simplicity first, elegant restraint, subtle motion. No over-decoration, no aggressive animations, no redundant icons/labels, no "just in case" features.

## Plex specifics

- TV hierarchy: Show (`grandparentRatingKey`) → Season (`parentRatingKey`) → Episode (`ratingKey`, `index`, `parentIndex`). Continue Watching items may lack parent metadata — fetch via `PlexNetworkManager.getMetadata()`.
- Discover API uses three hosts: `discover.provider.plex.tv` (watchlist CRUD), `metadata.provider.plex.tv` (metadata matches), `metadata-static.plex.tv` (image CDN, no auth). Watchlist needs account-level `authToken` (NOT `selectedServerToken`), `includeGuids=1`, and rejects `X-Plex-Container-Size`. Mutations resolve external GUID → discover `ratingKey` first.
- Live TV routes through RPlayer (`MultiStreamViewModel`/`StreamSlotView` per slot). HDHomeRun gives a direct stream; DVB tuners (TBS etc.) need a Plex transcode URL (`/video/:/transcode/universal/start.m3u8`) with full client-profile params (`X-Plex-Client-Profile-Name/-Extra`, `mediaIndex`, `partIndex`, `offset`, `container`, `segmentFormat`/`segmentContainer`, `videoCodec`, `videoResolution`, `maxVideoBitrate`, `videoQuality`, `audioCodec`, `audioBitrate`, `audioChannels`, unique `session`). Minimal URLs fail — see `PlexLiveTVModels.buildPlexLiveTVStreamURL()`.

## Build

```bash
xcodebuild -scheme Rivulet -destination 'platform=tvOS Simulator,name=Apple TV' build
xcodebuild -scheme Rivulet -destination 'platform=tvOS,name=My Apple TV' build   # device
```

## Working rules

- Reuse existing app patterns first; verify Apple/Plex APIs against docs before coding — never guess.
- Player pipeline changes: validate with real playback, not build success.
- Conventional commits (`{type}({scope}): {description}`); feature branches + PRs; never push to `main`; never auto-merge.
- AI review: Codex + Sentry/Seer only. Reply on each review thread individually, resolve, wait for re-review; never push fixes silently.
- Push/PR only against the `Artic0din/Rivulet` fork (`origin`), never `upstream`.
