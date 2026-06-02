# Playback Routing & Fallback Policy (E4-PR3)

Date: 2026-06-02
Status: pure policies extracted + tested + documented. **AVKit-first ratified by
the Project Owner**, but this slice does **not** flip the default — the policies
mirror current runtime exactly (`avKitFirst` defaults `false`) and are **not yet
wired** into the live pipeline, so playback behaviour is unchanged. The default
flip remains **E4-PR6**.
Implementation: `Rivulet/Services/Plex/Playback/Pipeline/PlaybackRoutingPolicy.swift`.
Tests: `RivuletTests/Unit/Playback/PlaybackRoutingPolicyTests.swift`.

---

## 1. AVKit-first ratification

The Project Owner has ratified AVKit-first as the Epic 4 playback routing policy
(architecture report §6 Q1): `AVPlayerViewController` becomes the default
presentation for routes it can serve natively or via local remux / HLS, with
RPlayer retained as the **capability fallback** (DV P7/P8.6, lossless/exotic
audio, high-bitrate 4K-over-HTTP). Ratification authorises the *direction*; the
behaviour flip is staged and flag-gated in E4-PR6, not here.

## 2. Behaviour preservation

These policies are faithful mirrors of the existing decisions:

- **Route family** mirrors `ContentRouter.plan(for:)` branch-for-branch.
- **Player selection** mirrors `UniversalPlayerViewModel`: RPlayer unless
  `useApplePlayer` is set OR the video must be transcoded; `avKitFirst`
  (default **false**) is the future flip.
- **`useLocalRemux`** mirrors UPVM: `true` on the RPlayer path, `!useApplePlayer`
  on the AVPlayer path.
- **Fallback** mirrors "RPlayer fatal → HLS once" (`hasAttemptedRivuletHLSFallback`)
  and "AVKit has no automatic route fallback".

Because `avKitFirst` defaults off and nothing is wired, the live route for every
input is identical to today (locked by tests).

## 3. Route policy cases (`PlaybackRoutingPolicy`)

Inputs (`RoutingInput`, already-derived, no provider call): `isLiveTV`,
`forceHLS`, `videoRequiresTranscode` (MPEG-2/VC-1/VP9/AV1/HLG), `ffmpegAvailable`,
`needsRemux`, `needsDVConversion`, `canBuildDirectRoute`, `useApplePlayer`,
`avKitFirst`.

Outputs (`IntendedRoute`): `avKitDirect`, `avKitHls`, `avKitLocalRemux`,
`rPlayerDirect`, `rPlayerHls`, `rPlayerLocalRemux`.

Family decision order (mirrors `ContentRouter.plan`):

1. Live TV → HLS.
2. Forced HLS → HLS.
3. Video requires transcode → HLS (AVKit consumes it).
4. FFmpeg unavailable → native container → AVPlayer-direct; else HLS.
5. Native container + buildable direct route → AVPlayer-direct.
6. Needs remux AND (useLocalRemux OR DV conversion) AND buildable → local remux.
7. Needs remux → server HLS.
8. Otherwise → HLS fallback.

Player overlay: `avKit` iff `useApplePlayer || videoRequiresTranscode ||
avKitFirst`, else `rivulet`. Combined → the six `IntendedRoute` cases. Key
examples (today, `avKitFirst=false`):

| Content | IntendedRoute |
| --- | --- |
| Native MP4 + native audio | `rPlayerDirect` (`avKitDirect` if `useApplePlayer`) |
| DV P7 / P8.6 | `rPlayerLocalRemux` |
| TrueHD / DTS-HD / DTS:X | `rPlayerLocalRemux` |
| MPEG-2 / VC-1 / VP9 / AV1 / HLG | `avKitHls` (must transcode) |
| Remux needed + `useApplePlayer`, no DV | `avKitHls` (server remux) |
| Live TV / forced HLS | `rPlayerHls` (or `avKitHls` if must-transcode) |

Subtitles (PGS/ASS/SRT) are **not** a routing input — track selection is owned by
the subtitle pipeline — so they never alter the route (matches current behaviour).

## 4. Fallback policy cases (`PlaybackFallbackPolicy`)

Inputs (`FallbackInput`): failing `player`, `attemptedFamily`, `failure`
category, `hlsFallbackAlreadyAttempted`, `hlsRouteAvailable`.

Decisions (`PlaybackFallbackDecision`): `fallback(.hls)` / `stopWithError` /
`noFallback`. Rules (deterministic, **loop-free** — at most one hop):

- Already on HLS → `stopWithError` (terminal route).
- One-shot HLS fallback already spent, or no HLS available → `stopWithError`.
- RPlayer fatal (demux/decode/runtime/unsupported/network) → `fallback(.hls)` once.
- AVKit failure → `noFallback` (user-initiated retry only, as today).

No infinite loops / retry storms: the single one-shot is guarded by
`hlsFallbackAlreadyAttempted`, exactly mirroring `hasAttemptedRivuletHLSFallback`.

## 5. Telemetry integration

`PlaybackRoutingPolicy.telemetryRoute(_:)` maps an `IntendedRoute` to the
anonymised `PlaybackTelemetry.RouteName` (never a URL). Tests prove the resulting
`routeSelected` payloads are allow-listed and secret-free. **Live emission is
deferred** (no wiring this slice) — `routeSelected`/`routeFellBack`/`startup*`
are emitted when the policies are integrated (E4-PR6 flip / E4-PR5 recovery),
tracked under `DEBT-E4-PR2-001`. This avoids behaviour risk in a pure-extraction
slice.

## 6. What remains flag-gated / deferred

- **Default flip → E4-PR6**: set `avKitFirst = true` behind a staged flag; requires
  the media corpus + physical Apple TV device gate.
- **Live wiring of these policies into `ContentRouter`/UPVM → E4-PR6** (with the
  flip), or earlier behind a no-op flag if a behaviour-preserving integration is
  proven. Not done here.
- **Live telemetry emission → E4-PR3 integration / E4-PR5** (`DEBT-E4-PR2-001`).

## 7. Corpus / device dependencies for later route changes

Any actual routing change (E4-PR6) is gated by the media-validation corpus
(`DEBT-E1-PR1-004`) and a physical Apple TV 4K + HDR + Atmos environment — DV/HDR
dynamic-range, Atmos passthrough, and startup/rebuffer timing cannot be validated
on the simulator. See `epic-4-readiness-review.md` §4–5.

---

## Live integration (E4-PR5B, 2026-06-02)

**`PlaybackRoutingPolicy.player()` is now LIVE** as the single source for the
player choice in `UniversalPlayerViewModel.startPlayback`: the historical
`!useApplePlayer && !mustUseAVPlayer` rule is replaced by
`PlaybackRoutingPolicy.player(RoutingInput(videoRequiresTranscode:, useApplePlayer:, avKitFirst: false))`.
`avKitFirst` is passed `false`, so the runtime player selection is identical
(verified by `PlaybackPolicyIntegrationTests.testPlayerSelectionMatchesLegacyRule`
over all four input combinations). No default flip.

**Deferred (still `DEBT-E4-PR3-001`):**

- **Route-family replacement in `ContentRouter.plan`.** Not wired: `plan` owns
  URL construction *and* the `reasoning` strings that `ContentRouterPlaybackPlanTests`
  pin. `routeFamily` is a proven faithful mirror, but swapping the live branch
  for it risks reasoning/route regressions in the constraint-heavy router. Left
  in place; debt open for this path.
- **`PlaybackFallbackPolicy` wiring — BLOCKED by a model discrepancy discovered
  during integration.** The live AVPlayer path (`startWithFallback` /
  `attemptRivuletHLSFallback`) **does** fall back to HLS once on a direct/remux
  startup or item failure, but `PlaybackFallbackPolicy.decide` currently returns
  `.noFallback` for `player == .avKit`. Wiring it as-is would change behaviour
  (suppress the AVPlayer→HLS fallback). The policy's player-discrimination must
  be corrected first (fallback is keyed on `planHasHLSFallback` + one-shot guard,
  not on the player) before it can be the live decision source. Tracked under
  `DEBT-E4-PR3-001`; no wiring done here.
