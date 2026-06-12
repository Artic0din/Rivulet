# E4 Device-Gate — Media Corpus & Physical Device Readiness Pack

Date: 2026-06-03
Status: **Readiness & validation planning only. No app code, no playback /
routing / UX changes.** This pack defines the mandatory media corpus, the
physical Apple TV validation setup, the step-by-step test procedure, and the
precise Go/No-Go criteria that **must** be satisfied before **E4-PR6** (the
AVKit-first default flip + remaining route wiring) may begin.

Gates: `DEBT-E1-PR1-004` (live Plex fixture/UAT evidence) and the
device-environment gate referenced by `DEBT-E4-PR3-001` / `DEBT-E4-PR5-001`.

---

## 0. Why this gate exists

The simulator cannot validate the things E4-PR6 changes: real VideoToolbox
hardware decode of HEVC/DV, HDR10/Dolby Vision/HLG dynamic-range switching
(`DisplayCriteriaManager` → `AVDisplayManager` Match-Content), Atmos/lossless
audio passthrough over HDMI/eARC, AirPlay transport, and sustained 4K HEVC HTTP
throughput (`URLSessionAVIOSource`). The AVKit-first flip changes which engine
renders the majority of content, so each route must be proven on a physical
Apple TV 4K against real media **before** the default changes.

**Routing baseline (today, `avKitFirst = false`):** player = RPlayer unless
`useApplePlayer` is set OR the video codec forces a transcode
(MPEG-2 / VC-1 / VP9 / AV1 / MPEG-4 Part 2 / HLG). So nearly all content plays
through RPlayer DirectPlay today; forced-transcode video plays through AVPlayer
HLS.

**Routing target (post-flip, `avKitFirst = true`, E4-PR6):** player = AVKit by
default; `ContentRouter` family decides AVPlayer-direct (native container +
native audio + no DV P7) vs local remux (MKV / DV P7·P8.6 / non-native audio)
vs Plex HLS (server transcode / live TV). **RPlayer becomes the capability
fallback** for what AVKit cannot render natively (DV P7/P8.6 RPU rewrite,
lossless TrueHD/DTS-HD/DTS:X decode, high-bitrate edge cases). Designing and
proving that capability fallback is the core of E4-PR6 — hence this corpus.

Legend for the matrices:

- **Route(before)** — expected route with `avKitFirst = false` (current default).
- **Route(after)** — expected route with `avKitFirst = true` (E4-PR6 target).
- **Fallback** — expected automatic fallback if the primary engine fails
  (per E4-PR5C: AVPlayer→HLS once; RPlayer terminal→error→user-retry; the
  AVKit-first *capability* fallback to RPlayer is the new E4-PR6 behaviour to prove).
- **Critical?** — ✅ = a critical route category that **must** have ≥1 sample for
  E4-PR6 Go (Scope 5).

---

## Scope 1 — Media Corpus Matrix

### 1A. Video / HDR / container

| # | Category | Crit? | Sample title/file | Plex metadata (expected) | Route(before) | Route(after flip) | Fallback if native fails | Subtitle exp. | Audio exp. | HDR/DV exp. | Required device/display | Pass/Fail notes |
|---|----------|:----:|-------------------|--------------------------|---------------|-------------------|--------------------------|---------------|------------|-------------|-------------------------|-----------------|
| V1 | H.264 SDR | ✅ | _TBD_ | `videoCodec=h264`, MP4 | RPlayer DirectPlay | AVPlayer direct (native MP4) | AVPlayer→HLS once | per track | passthrough | SDR | |
| V2 | HEVC SDR | ✅ | _TBD_ | `videoCodec=hevc`, MP4/MKV | RPlayer DirectPlay | MP4→AVPlayer direct; MKV→local remux | AVPlayer→HLS / RPlayer cap-fallback | per track | passthrough | SDR | SDR | |
| V3 | HEVC HDR10 | ✅ | _TBD_ | `hevc`, `colorTrc=smpte2084`, BT.2020 | RPlayer DirectPlay (VT HW) | AVPlayer direct/remux; **RPlayer fallback for HDR fidelity** | RPlayer cap-fallback | per track | passthrough | **HDR10 display**; Match-Content on | Verify HDR10 engages on panel |
| V4 | Dolby Vision P5 | ✅ | _TBD_ | `hevc` dvProfile=5 | RPlayer DirectPlay (native P5) | RPlayer (DV native) or AVPlayer if proven | RPlayer cap-fallback | per track | passthrough | **DV display** | Verify DV mode on panel |
| V5 | Dolby Vision P8.1 | ✅ | _TBD_ | dvProfile=8 blCompat=1 | RPlayer DirectPlay (native P8.1) | RPlayer (DV native) | RPlayer cap-fallback | per track | passthrough | **DV display** | |
| V6 | Dolby Vision P7 MEL | ✅ | _TBD_ | dvProfile=7 (MEL) | RPlayer (RPU rewrite P7→P8.1) or local remux | local remux / RPlayer (RPU rewrite) | RPlayer cap-fallback | per track | passthrough | **DV display** | P7 is RPlayer/remux-only; AVPlayer cannot |
| V7 | Dolby Vision P7 FEL | ⚠️ if avail | _TBD_ | dvProfile=7 (FEL) | RPlayer (RPU rewrite) / remux | as P7 MEL | RPlayer cap-fallback | per track | passthrough | **DV display** | Confirm FEL handling/limits |
| V8 | Dolby Vision P8.6 | ⚠️ if avail | _TBD_ | dvProfile=8 blCompat=6 | RPlayer (RPU rewrite P8.6→P8.1) | RPlayer (RPU rewrite) | RPlayer cap-fallback | per track | passthrough | **DV display** | |
| V9 | HLG | ✅ | _TBD_ | `colorTrc=arib-std-b67`/hlg | **AVPlayer HLS (forced transcode)** | AVPlayer HLS (forced transcode) | (already HLS) → error | per track | passthrough | HLG/HDR display | HLG black on AVSBL → must transcode |
| V10 | MPEG-2 | ✅ | _TBD_ | `videoCodec=mpeg2video` | **AVPlayer HLS (forced transcode)** | AVPlayer HLS (forced transcode) | (already HLS) → error | per track | transcoded | SDR | No native decoder |
| V11 | VC-1 | ✅ | _TBD_ | `videoCodec=vc1`/wmv3 | **AVPlayer HLS (forced transcode)** | AVPlayer HLS | (already HLS) → error | per track | transcoded | SDR | No native decoder |
| V12 | VP9 | ✅ | _TBD_ | `videoCodec=vp9` | **AVPlayer HLS (forced transcode)** | AVPlayer HLS | (already HLS) → error | per track | transcoded | SDR/HDR | No Apple TV HW decoder |
| V13 | AV1 | ✅ | _TBD_ | `videoCodec=av1` | **AVPlayer HLS (forced transcode)** | AVPlayer HLS | (already HLS) → error | per track | transcoded | SDR/HDR | No HW decoder (≤A15) |
| V14 | High-bitrate 4K HEVC over HTTP | ✅ | _TBD_ (≥50 Mbps) | `hevc` 2160p high bitrate | RPlayer DirectPlay (`URLSessionAVIOSource`) | RPlayer (sustained-throughput path) | RPlayer cap-fallback | per track | passthrough | 4K display; LAN | Verify no stall; parallel ranged GET |
| V15 | MKV container | ✅ | _TBD_ | `container=matroska` | RPlayer DirectPlay | local remux (MKV→fMP4) | AVPlayer→HLS / RPlayer | per track | passthrough | any | |
| V16 | MP4/MOV/M4V container | ✅ | _TBD_ | `container=mp4/mov` + native audio | RPlayer DirectPlay | AVPlayer **direct** | AVPlayer→HLS once | per track | passthrough | any | The canonical AVPlayer-direct case |

### 1B. Audio

| # | Category | Crit? | Sample (container) | Plex metadata | Route(before) | Route(after flip) | Fallback | Audio behaviour expected | Required audio path | Pass/Fail |
|---|----------|:----:|--------------------|---------------|---------------|-------------------|----------|--------------------------|---------------------|-----------|
| A1 | AAC stereo | ✅ | MP4 | `audioCodec=aac` ch=2 | RPlayer passthrough | AVPlayer direct | AVPlayer→HLS | Native passthrough | any | |
| A2 | AC-3 5.1 | ✅ | MKV/MP4 | `ac3` ch=6 | RPlayer passthrough | AVPlayer direct/remux | AVPlayer→HLS | 5.1 bitstream | 5.1 receiver | Receiver shows "Dolby Digital" |
| A3 | E-AC-3 | ✅ | MKV | `eac3` | RPlayer passthrough | local remux / AVPlayer | AVPlayer→HLS | EAC3 bitstream | receiver | |
| A4 | E-AC-3 Atmos (JOC) | ✅ | MKV | `eac3` + Atmos/JOC | RPlayer passthrough | local remux (passthrough) | RPlayer | **Atmos rendered** | **Atmos path (eARC/AVR)** | AVR shows "Dolby Atmos" |
| A5 | TrueHD | ✅ | MKV | `truehd` | RPlayer (FFmpeg decode→PCM) | **RPlayer (lossless decode)** | error | Decoded to PCM (lossless) | receiver | AVPlayer can't → RPlayer cap |
| A6 | TrueHD Atmos | ⚠️ if avail | MKV | `truehd` + Atmos | RPlayer decode→PCM | RPlayer | error | PCM (Atmos metadata loss expected) | AVR | Document Atmos-over-PCM limitation |
| A7 | DTS | ✅ | MKV | `dts`/`dca` | RPlayer (FFmpeg decode→PCM) | RPlayer (decode) or Plex HLS transcode | RPlayer/HLS | Decoded to PCM | receiver | |
| A8 | DTS-HD MA | ✅ | MKV | `dts-hd`/`dtshd` | RPlayer decode→PCM | RPlayer | error | PCM (lossless) | receiver | |
| A9 | DTS:X | ⚠️ if avail | MKV | `dts` + X | RPlayer decode→PCM | RPlayer | error | PCM (object audio loss expected) | AVR | Document DTS:X limitation |
| A10 | PCM | ✅ | MKV/MOV | `pcm*` | RPlayer (passthrough/decode) | RPlayer/remux | error | PCM | receiver | |
| A11 | FLAC | ✅ | MKV | `flac` | RPlayer (decode→PCM) | RPlayer | error | PCM | any | |

### 1C. Subtitles

| # | Category | Crit? | Sample | Plex metadata | Expected subtitle behaviour | Notes | Pass/Fail |
|---|----------|:----:|--------|---------------|-----------------------------|-------|-----------|
| S1 | No subtitles | ✅ | any | no sub streams | No subtitle UI track; off | | |
| S2 | SRT (internal/external) | ✅ | MKV / sidecar | `codec=srt` | Text overlay (`SubtitleParser`) | | |
| S3 | WebVTT | ✅ | HLS/MP4 | `codec=webvtt` | Text overlay | | |
| S4 | PGS | ✅ | MKV | `codec=pgs` | Bitmap overlay (`FFmpegSubtitleDecoder`) | `end=UInt32.max` = until-next sentinel | |
| S5 | ASS/SSA | ✅ | MKV | `codec=ass`/`ssa` | Text overlay (styling best-effort) | | |
| S6 | Forced subtitles | ✅ | MKV | `forced=1` | Auto-selected for foreign-audio segments | | |
| S7 | Multiple subtitle tracks | ✅ | MKV | ≥2 sub streams | All selectable; switch live | | |
| S8 | Default subtitle selection | ✅ | MKV | `default=1` / pref manager | Correct default per `SubtitlePreferenceManager` | | |

### 1D. Content types / flows

| # | Category | Crit? | Sample | Expected behaviour | Watch-state / route notes | Pass/Fail |
|---|----------|:----:|--------|--------------------|---------------------------|-----------|
| C1 | Movie | ✅ | _TBD_ | Resume/restart prompt per setting; route per codec | `PlaybackResumePolicy` | |
| C2 | TV episode | ✅ | _TBD_ | Same; episode offset | | |
| C3 | Next episode available | ✅ | _TBD_ | Post-play next-up offered | post-play (custom overlay today; `AVContentProposal` = E4-PR9) | |
| C4 | Completed series | ✅ | _TBD_ | No spurious next-up | | |
| C5 | Trailer / extra | ✅ | _TBD_ | No resume; plays from 0 | `isTrailer` → start at beginning | |
| C6 | Live TV | ✅ | _TBD_ | HLS route; no resume | `isLive` → HLS, never resumes | |
| C7 | DVR recording | ⚠️ if avail | _TBD_ | Plays as VOD-style recording | DVB transcode params if applicable | |

---

## Scope 2 — Ryan Library Inventory Checklist

Goal: identify ≥1 owned file per **Critical?** row above. **No files are
shared** — only confirm a matching title exists and note the row it satisfies.

How to read media properties in Plex (web/desktop):

- **Codecs (video/audio):** open the item → **⋯ → Get Info → Media Info** (or
  "View XML"). Look at `videoCodec`, `audioCodec`, `container`, `bitrate`,
  `videoResolution`, `Stream` entries. The "View XML" link shows the exact Plex
  metadata Rivulet routes on (`Media`/`Part`/`Stream`).
- **Audio format & channels:** Media Info shows audio `codec` + `channels`
  (e.g. `eac3 / 6ch`). Atmos/JOC and DTS:X often appear in the stream title or
  `audioChannelLayout` / display title (e.g. "TrueHD Atmos 7.1").
- **Subtitle type:** Media Info lists subtitle `Stream` `codec`
  (`srt`/`ass`/`pgs`/`vtt`), plus `forced` and `default` flags and language.
- **Dolby Vision profile:** in the XML look for the DV stream attributes
  (`DOVIProfile` / `dvProfile`, `dvBLCompatID`). Profile 5, 7 (MEL/FEL),
  8.1 (blCompat 1), 8.6 (blCompat 6). If the server doesn't expose it, the file
  name / release notes usually state "DV P7 FEL", etc.
- **HDR10 vs HLG:** check the video stream `colorTrc` — `smpte2084` (PQ) =
  HDR10; `arib-std-b67` or `hlg` = HLG. BT.2020 primaries indicate wide gamut.
- **Direct play vs transcode (live check):** start the item on the Apple TV,
  then in Plex server **Settings → Status → Now Playing** observe the session:
  "Direct Play" / "Direct Stream" / "Transcode (video/audio)". This is the
  ground truth to compare against the corpus's expected route.

Deliverable: tick each Critical row that has a matching owned title; flag any
Critical row with **no** match as a **corpus gap** (see Scope 5 — those must be
sourced or the category explicitly waived by the Project Owner).

---

## Scope 3 — Physical Device Requirements

**Required:**

- Apple TV 4K (physical device; note model/chip — A12/A15 affects AV1/decode).
- HDR-capable display (HDR10 minimum; Dolby Vision for V4–V8).
- Apple TV on the **same LAN** as the Plex Media Server.
- Plex server reachable over LAN; server **Now Playing** accessible for route
  ground-truth.
- Stable network (wired Apple TV preferred for V14 high-bitrate).
- Xcode install/deploy path: device paired, developer mode on, signing set;
  `xcodebuild -scheme Rivulet -destination 'platform=tvOS,name=<Apple TV>'`.

**Recommended:**

- Atmos-capable audio path (AVR/soundbar over HDMI eARC) for A4/A6.
- A way to force/observe SDR (SDR display or TV SDR mode) to validate
  dynamic-range switching both directions.
- Multiple network conditions (wired vs Wi-Fi; optional shaped/throttled).
- Receiver/soundbar that **displays the decoded audio format** (the only
  reliable Atmos/DD+/DTS confirmation).
- TV info panel that **displays HDR/DV mode** (to confirm Match-Content).

**Optional:**

- AirPlay target (for the AirPlay-instability recovery ladder, `DEBT-E4-PR5-001`).
- Bluetooth headphones (stereo downmix path).
- External subtitle sidecars with mixed encodings (UTF-8 / Latin-1).

---

## Scope 4 — Test Procedure (per corpus sample)

Run each applicable flow; record route from Plex **Now Playing** + on-device
behaviour. Capture pass/fail in the row's notes field.

1. **Launch playback** from detail → confirm loading → playing.
2. **Verify initial route** — compare on-screen engine + Plex Now Playing
   (Direct Play / Direct Stream / Transcode) against Route(before) / Route(after).
3. **Direct-play / direct-stream / transcode** — confirm the expected mode (not
   an unexpected server transcode).
4. **Seek** forward and back (incl. >30 s jumps); confirm A/V sync holds.
5. **Pause / resume** — confirm resume from the same position, no drift.
6. **Background / foreground** — Home button out, return; confirm it stays
   paused and resumes cleanly on play (matches `decide(.appBackgrounded)`).
7. **App relaunch resume** — quit, relaunch, Resume → confirm offset prompt /
   resume position (`PlaybackResumePolicy`).
8. **Subtitle selection** — switch tracks live; forced + default behaviour.
9. **Audio track selection** — switch tracks; confirm format on receiver.
10. **Chapter navigation** — skip chapters / intro / credits markers.
11. **Trailer playback** — starts at 0; no resume; returns cleanly.
12. **Post-play** — next-up / replay behaviour at end of episode/movie.
13. **Fallback** — force a primary failure where feasible (e.g. unsupported on
    AVPlayer) → confirm the expected fallback (AVPlayer→HLS once; or RPlayer
    capability fallback post-flip) and **no fallback loop**.
14. **Error handling** — induce a hard failure (bad source) → calm, redacted
    on-screen error; user retry works.
15. **Stop / return to detail** — Menu/stop → returns to detail; player torn down.
16. **Continue Watching update** — confirm progress reported and the item
    appears/updates in Continue Watching (Epic 1 watch-state; consume-only here).

Telemetry check (non-blocking): confirm `routeSelected` / `routeFellBack`
signposts fire with anonymised values only (no URL/token) via Console/Instruments.

---

## Scope 5 — E4-PR6 Go/No-Go Criteria

**E4-PR6 may begin only when ALL of the following hold:**

1. **Corpus coverage** — ≥1 owned sample for **every Critical (✅) row** in
   Scope 1 (V1–V6, V9–V16, A1–A5, A7, A8, A10, A11, S1–S8, C1–C6). Any missing
   Critical category is either sourced or **explicitly waived by the Project
   Owner** (waiver recorded in this pack).
2. **Device** — a physical Apple TV 4K is available and deploys from Xcode.
3. **HDR validation possible** — an HDR10 display at minimum; Dolby Vision
   display for V4–V8 (or those rows waived).
4. **Advanced audio** — ≥1 advanced-audio path validated (Atmos **or** lossless
   TrueHD/DTS-HD) **or** explicitly waived by the Project Owner.
5. **Subtitle samples** — SRT, PGS, and ASS samples present (S2, S4, S5).
6. **Rollback plan** — the flip ships behind a flag with `avKitFirst` default
   **revertible without a rebuild path documented** (UserDefault / remote flag),
   and a one-line revert to RPlayer-first is verified.
7. **Telemetry safe** — `routeSelected` / `routeFellBack` confirmed secret-free
   on-device (no URL/token in signposts or Sentry breadcrumbs).
8. **Known fallback behaviour documented** — the post-flip AVKit→RPlayer
   capability fallback ladder is specified (which categories fall back, one-shot,
   loop-free) and the corpus rows that exercise it are identified (V3–V8, A4–A11).

**No-Go if** any Critical category has no sample and no waiver, no physical
device/HDR path, or no rollback plan.

---

## Scope 6 — Ownership & sign-off

- **Corpus assembly + library inventory:** Ryan (Project Owner).
- **Device/display/audio environment:** Ryan.
- **Procedure execution + result capture:** Epic 4 owner with Ryan on-device.
- **Go/No-Go decision:** Project Owner, recorded here and in
  `epic-4-readiness-review.md`.

This pack is the single source for the E4-PR6 entry gate; results fill the
pass/fail columns and the Go/No-Go checklist before any default flip.
