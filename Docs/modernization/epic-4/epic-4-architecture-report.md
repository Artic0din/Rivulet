# Epic 4 — Playback Excellence — Architecture Report (Planning Only)

Date: 2026-06-01
Status: **Planning only.** No Epic 4 implementation is authorised by this
document. Produced after Epic 3 closure per the modernization mandate.
Owner: Epic 4 owner (with Epic 1 owner support for watch-state boundaries).

Inputs: read-only audit of `Services/Plex/Playback/**`, `Views/Player/**`,
`Docs/RIVULET_PLAYER.md`, `Docs/PLAYER_INTERNALS.md`, the Epic 0 governance
package, and Epic 1's watch-state boundary (`PlexProgressReporter`,
`PlexWatchStateRequestFactory`).

---

## 1. Current playback architecture (as-built)

Two players coexist; `ContentRouter.plan(...)` returns a `PlaybackPlan { primary,
fallbacks, policy }` and `UniversalPlayerViewModel` selects the player by route.

### 1.1 Routes (`PlaybackRoute`)
- `.avPlayerDirect(url, headers)` — natively-playable MP4 + native audio, no DV
  P7 → AVPlayer (`NativePlayerViewController`).
- `.localRemux(url, headers, analysis)` — MKV / DV P7 / DTS / TrueHD → served by
  `LocalRemuxServer` (FFmpeg remux → HLS on localhost) → AVPlayer.
- `.hls(url, headers)` — Plex transcode / fallback → AVPlayer.
- RPlayer DirectPlay (not a `PlaybackRoute` case — selected when FFmpeg can demux
  locally and AVPlayer isn't preferred): FFmpeg demux + VideoToolbox + sample-
  buffer render.

### 1.2 Routing policy (`RoutingPolicy`, e.g. `.directPlayFirst`)
`useApplePlayer` UserDefault biases toward AVPlayer paths. Hard blockers start on
`.hls` immediately (FFmpeg unavailable, no direct-play part key, forced HLS).

### 1.3 Player state (`PlayerProtocol`)
`.idle / .loading / .playing / .paused / .buffering / .ended / .failed(PlayerError)`.

### 1.4 Watch-state boundary (Epic 1-owned — must not change)
`PlexProgressReporter.reportProgress(...)`, `markAsWatched`, `markAsUnwatched`,
built through `PlexWatchStateRequestFactory`. Epic 4 consumes timeline events but
does not change who owns watch-state writes or the request contract.

### 1.5 Codec routing (RPlayer)
H.264/HEVC/DV P5/P8.1 → VideoToolbox; DV P7/P8.6 → RPU rewrite (HEVCNALParser +
LibdoviWrapper) → VideoToolbox; AAC/AC3/EAC3 passthrough; TrueHD/DTS/PCM/FLAC →
FFmpegAudioDecoder → PCM. Display switching via `DisplayCriteriaManager` →
`AVDisplayManager` (Match Content frame-rate + dynamic range).

---

## 2. The Epic 4 tension: AVKit-first vs RPlayer-first

The roadmap names an **AVKit-first / AVPlayerViewController-first** policy. The
current default is **direct-play-first** (RPlayer unless `useApplePlayer`). Epic 4
must decide the canonical policy and the fallback ladder. This report frames the
decision; it does not make irreversible changes.

| Dimension | AVPlayer (AVKit) | RPlayer (FFmpeg + sample buffer) |
| --- | --- | --- |
| tvOS-native transport UI, AirPlay, Now Playing, focus | First-party, robust | Custom, more maintenance |
| Codec breadth | Native set only (+ HLS transcode / local remux) | Broad (TrueHD/DTS/PCM/FLAC, DV P7/P8.6 rewrite) |
| 4K HEVC/DV over HTTP | Via HLS/remux | Direct, via `URLSessionAVIOSource` |
| Startup latency | Low for native; remux adds spin-up | Preroll ~200–450 ms |
| Maintenance / risk surface | Low (Apple-owned) | High (custom pipeline) |

**Framing recommendation (for Epic 4 to ratify):** make
`AVPlayerViewController` the **default presentation** for routes it can serve
natively or via local remux/HLS, and keep RPlayer as the **capability fallback**
for content AVKit cannot play faithfully (e.g. DV P7 where remux is unavailable,
exotic audio). This inverts today's default while preserving RPlayer's unique
coverage. It is a policy + presentation change, not a pipeline rewrite.

---

## 3. Route decision matrix (proposed target)

| Content | Primary (proposed) | Fallback 1 | Fallback 2 | Notes |
| --- | --- | --- | --- | --- |
| MP4 H.264/HEVC + AAC/AC3/EAC3 | AVPlayer direct | HLS | — | Native; lowest latency |
| MKV (compatible video) + native audio | Local remux (AVPlayer) | RPlayer DirectPlay | HLS | Remux avoids transcode |
| TrueHD / DTS / PCM / FLAC audio | Local remux or RPlayer | HLS | — | RPlayer if remux can't carry audio losslessly |
| DV P5 / P8.1 | AVPlayer direct/remux | RPlayer | HLS | Native DV |
| DV P7 MEL / P8.6 | RPlayer (RPU rewrite) | local remux if viable | HLS | RPlayer's unique capability |
| 4K HEVC/DV high-bitrate over HTTP | RPlayer (`URLSessionAVIOSource`) | HLS | — | Throughput-proven path |
| FFmpeg unavailable / no part key / forced HLS | HLS | — | — | Hard blocker → HLS now |

This matrix is a **planning target**, to be validated against the media corpus
(`media-validation-corpus.md`) before any routing change ships.

---

## 4. Topic-by-topic plan

- **AVKit-first / AVPlayerViewController-first**: introduce a routing-policy value
  (e.g. `.avkitFirst`) and make AVPlayer the default presentation; gate behind a
  flag for staged rollout; preserve `useApplePlayer` semantics during migration.
- **RPlayer fallback strategy**: deterministic, tested fallback ladder; one
  fallback per failure at current playback time (matching today's "RPlayer fatal
  → HLS once" behaviour); a pure `PlaybackFallbackPolicy` is the natural seam.
- **Dolby Vision / HDR**: no change to RPU rewrite or `DisplayCriteriaManager`
  logic in Epic 4 beyond routing; correctness validated on-device against the
  corpus. DV P7/P8.6 remain RPlayer-owned.
- **Subtitles / audio**: no routing change; verify track selection parity across
  AVPlayer and RPlayer; document the matrix. Lossless audio stays RPlayer/remux.
- **Resume / session correctness**: a single source of truth for start offset and
  resume; dedupe seek-on-resume; verify resume position across all routes.
- **Interruption / failure recovery**: deterministic recovery ladder (network
  loss, transcode failure, decode fatal) → fallback route at current time;
  surfaced via the existing `.failed(PlayerError)` state with calm,
  redacted-copy errors (reuse the Epic 2 `HomeErrorPresentation`-style approach).
- **Playback telemetry**: define a telemetry contract (startup time, rebuffer,
  route taken, fallback reason) using `os_signpost`/structured logs only —
  **no third-party analytics**, no stream URLs/tokens in any sink (E0-G08).
- **Watch-state boundaries**: consume timeline events; do **not** change
  `PlexProgressReporter`/`PlexWatchStateRequestFactory` (Epic 1 boundary).
- **Playback security/privacy**: eliminate any stream-URL leakage to Sentry
  (the open Playback parity blocker `E0-OBS-002`/`E0-OBS-003`); all playback
  diagnostics use `SensitiveDataRedactor`.

---

## 5. Risk register (planning)

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Inverting default to AVKit-first regresses exotic content | Playback breakage | Flag-gated staged rollout; corpus validation; RPlayer fallback retained |
| Routing change interacts with DV/HDR display switching | Wrong dynamic range | No DV/HDR logic change; on-device Match-Content validation per corpus |
| Resume/seek dedupe regressions across routes | Wrong start position | Pure `PlaybackResumePolicy` + tests; per-route UAT |
| Stream URL / token leakage in telemetry/Sentry | Security blocker | Redactor-first telemetry; no URL in any sink; explicit review |
| Watch-state contract drift | Reopens Epic 1 | Consume-only; no reporter/factory change |
| No media corpus / device locally | Unvalidated routing | Corpus-backed device validation is a hard pre-merge gate (`DEBT-E1-PR1-004`) |
| Custom RPlayer maintenance burden grows | Long-term cost | Keep RPlayer scoped to capability fallback; prefer AVKit where faithful |

---

## 6. Open questions for Project Owner

1. Ratify AVKit-first-as-default with RPlayer capability fallback? (vs keep
   direct-play-first.)
2. Telemetry sink: `os_signpost`/unified logging only, or also Sentry
   breadcrumbs (with strict redaction)? (DSN ownership `DEBT-E1-PR2-001`.)
3. Acceptable staged-rollout mechanism (flag, percentage, per-codec)?

---

## 7. Recommendation

**Epic 4 is ready to plan in detail but should not begin implementation until:**
(a) the AVKit-first policy is ratified, (b) the media-validation corpus + a
physical Apple TV are available for the mandatory device gate, and (c) the
Playback Sentry stream-URL leakage blocker (`E0-OBS-002/003`) is scheduled as the
first slice. With those, Epic 4 can begin. See `epic-4-decomposition.md` for the
proposed slices. **No code in this epic has been written.**
