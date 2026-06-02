# Epic 4 — Playback Excellence — Readiness Review (Gate-Clearing Pass)

Date: 2026-06-01
Status: **Audit / planning / validation only. No Epic 4 implementation authorised.**
No playback, route, player, architecture, or project-setting change was made.
Owner: Epic 4 owner (Epic 1 owner supports watch-state boundaries).

Inputs: read-only audit of `Services/Plex/Playback/**`, `Views/Player/**`,
`Views/LiveTV/**`, the Epic 4 planning docs (`epic-4-architecture-report.md`,
`epic-4-decomposition.md`), `Docs/RIVULET_PLAYER.md`, `Docs/PLAYER_INTERNALS.md`,
the Epic 0 governance package, and the closure artifacts.

This pass exists to clear (or document) the four standing Epic 4 blockers:
(1) AVKit-first not ratified, (2) playback stream-URL / Sentry leak not scheduled,
(3) media-validation corpus not confirmed, (4) physical Apple TV not confirmed.

---

## Scope 1 — AVKit-First Decision Review

**Why AVKit-first was proposed.** The current default is *direct-play-first*
(RPlayer unless the `useApplePlayer` default is set). The roadmap names an
AVKit / `AVPlayerViewController`-first policy to lean on Apple's first-party
transport UI, AirPlay, Now Playing, focus, and HDR/Match-Content handling, and to
shrink the maintenance/risk surface of the custom RPlayer pipeline.

**Advantages.**

- First-party transport UI, AirPlay, Now Playing, Siri-remote transport, focus —
  robust and free.
- Lower maintenance and lower crash surface (Apple-owned decode/render).
- Lower startup latency for natively-playable content.
- Aligns with "don't fight the framework."

**Risks.**

- Inverting the default can regress exotic content (lossless audio, DV P7/P8.6,
  high-bitrate 4K HEVC/DV over HTTP) that RPlayer currently handles.
- Routing interacts with DV/HDR display switching (`DisplayCriteriaManager` →
  `AVDisplayManager`) — wrong dynamic range if mishandled.
- Local-remux spin-up adds latency for MKV/lossless paths.
- Resume/seek dedupe must stay correct across a changed primary route.

**Alternative approaches.**

- Keep direct-play-first (status quo) — lowest immediate risk, but keeps the
  high-maintenance custom path as the default and under-uses AVKit.
- Per-codec routing table only (no "first" default) — flexible but harder to
  reason about and validate.
- AVKit-first **default** with a deterministic RPlayer **capability fallback**
  (the architecture report's framing recommendation).

**What remains dependent on RPlayer (AVKit cannot do faithfully alone).**

- DV Profile 7 (MEL) and P8.6 → P8.1 on-the-fly RPU rewrite (`HEVCNALParser` +
  `LibdoviWrapper`).
- Lossless / exotic audio decoded to PCM (TrueHD, DTS-HD/DTS:X, PCM variants,
  FLAC) where local remux cannot carry it losslessly.
- High-bitrate 4K HEVC/DV over plain HTTP via `URLSessionAVIOSource` (parallel
  ranged GETs) — the throughput-proven path on tvOS.

**Whether AVKit-first still appears correct.** Yes. It is a **policy +
presentation-default** change, not a pipeline rewrite: make
`AVPlayerViewController` the default for routes it can serve natively or via
local remux / HLS, and keep RPlayer as the capability fallback for the cases
above. RPlayer's unique coverage is preserved; the default simply prefers the
lower-risk player where it is faithful.

### Decision: **YES — recommend ratifying AVKit-first-as-default with RPlayer capability fallback.**

Caveat: ratification is the **Project Owner's** call (architecture report §6 Q1).
This review recommends YES; it does not itself ratify. Implementation stays gated
on that sign-off and on a flag-gated, corpus-validated staged rollout (the flip
itself is E4-PR6, never PR1).

---

## Scope 2 — Playback Security & Observability Audit

Read-only audit of every Sentry / log surface in `Services/Plex/Playback/**`,
`Views/Player/**`, `Views/LiveTV/**`.

**Material finding — the literal E0-OBS-002 leak is already remediated in code.**
`E0-OBS-002` was filed as "player error path sends raw `stream_url` to Sentry
extras" in `UniversalPlayerViewModel`. The current error-capture scope
(`UniversalPlayerViewModel.swift` ~L1183) sets only `media_title`, `media_type`,
`rating_key`, and `start_offset` — **no URL**. A repo-wide search for any
`setExtra` carrying a raw URL / `absoluteString` / `stream_url` value returns
**empty**:

- HLS Sentry paths (`HLSSegmentFetcher`, `HLSPipeline`) log `host` / `path` /
  segment counts, and use `SensitiveDataRedactor.redactedURLValue` for
  `variant_url` / `master_url` / `stream_url`.
- Live TV (`MultiStreamViewModel`) logs `*_scheme` / `*_host` / `*_path`
  components and `redactedURLValue` for the `stream_url` key — never the raw URL.
- Breadcrumb messages in playback are static strings ("DirectPlay Load",
  "HLS Pipeline Load", "Playback selection (\<reason\>)") — no URLs/tokens.
- The HLS manifest-body leak (token-bearing rewritten URLs) was fixed this session
  (`SEC-HLS-001…006`): structural summary only, redacted errors.
- `FFmpegRemuxSession` passes `url.absoluteString` **as the `avformat_open_input`
  argument** (not a log sink) — not a leak.

**Remaining token / stream-URL exposure risk.** Low and not in a Sentry sink.
Token-bearing URLs are still *constructed* (they must be, to play) and the broad
`print()` usage across playback is not all routed through the redactor — that is
the residual of `E0-OBS-003` ("widespread `print()`; multiple `X-Plex-Token`
query constructions") and `DEBT-E1-PR1-006` / `KF-E0-004`. A targeted scan of
playback `print(...)` for URL/token interpolation found only a status-code print
(`HLSPreflight`), no URL bodies — but the audit was not exhaustive across every
file, so residual `print()` hygiene remains open debt, not a verified clean.

**Remaining Sentry risk.** Low. No raw URL/token reaches Sentry extras,
breadcrumbs, or messages in the audited paths. DSN ownership is tracked
(`DEBT-E1-PR2-001`); telemetry sink policy (signpost-only vs Sentry breadcrumbs)
is an open Project-Owner question (architecture §6 Q2).

**Remaining observability debt.** `E0-OBS-003` (broad `print()` migration to a
redacted, structured logger) and `KF-E0-004` remain open across playback.

### Recommended first Epic 4 security slice — E4-PR1 (revised scope)

- **Scope:** *verify and formally close* `E0-OBS-002` rather than fix-from-scratch
  (it appears already remediated): add **regression tests** asserting no playback
  Sentry sink (extras/breadcrumbs/messages) and no playback log carries a raw URL
  or `X-Plex-Token`; complete the exhaustive `print()`/diagnostic scan across
  `Services/Plex/Playback/**` and `Views/Player/**`; route any residual
  URL/token-bearing `print()` through `SensitiveDataRedactor`; document the result
  and close `E0-OBS-002` with evidence; scope the residual `E0-OBS-003` print
  migration as its own tracked item.
- **Estimated risk:** **Low.** Mostly verification, tests, and any small residual
  redaction — no routing/player/pipeline change. No corpus or device dependency,
  so E4-PR1 can proceed the moment Epic 4 is authorised, ahead of the other gates.

*(No issues fixed in this pass — findings only.)*

**Update (E4-PR1, 2026-06-01):** done. The exhaustive audit found one residual
console leak (`FFmpegDemuxer:235` logged `url.absoluteString`) — fixed to
`lastPathComponent` — and verified every other playback log/Sentry sink carries no
token/full URL. Regression tests added (`PlaybackObservabilityTests`).
`E0-OBS-002` **CLOSED**; `E0-OBS-003` **REDUCED** (security resolved; broad
`print()` migration remains as `DEBT-E1-PR1-006`/`KF-E0-004`). See
`playback-observability-audit.md`.

---

## Scope 3 — Playback Capability Inventory

Current state derived from `ContentRouter`/`UniversalPlayerViewModel`, the RPlayer
pipeline, `Docs/RIVULET_PLAYER.md`/`PLAYER_INTERNALS.md`, and the test set
(`ContentRouterPlaybackPlanTests`, `RouteAudioPolicyTests`, `SubtitleParserTests`,
`PlaybackStateTests`, `PlaybackInputCoordinatorTests`). Confidence reflects
test/desk evidence only — **no on-device runs exist yet** (`DEBT-E0-007/008`).

| Capability | Current state | Known limitations | Dependencies | Test coverage | Confidence |
| --- | --- | --- | --- | --- | --- |
| Direct Play | Live (AVPlayer for native MP4; RPlayer DirectPlay for FFmpeg-demuxable) | Route selection not yet a pure tested policy (inline in `ContentRouter`/VM) | `ContentRouter`, `URLSessionAVIOSource` | `ContentRouterPlaybackPlanTests` (plan shape) | Medium |
| Direct Stream (remux) | Live (`LocalRemuxServer` + `FFmpegRemuxSession`, HLS on localhost) | Spin-up latency; lossless-audio carriage limits | FFmpeg remux | Indirect | Low–Medium |
| Transcode (HLS) | Live (Plex `start.m3u8`; hard-blocker fallback) | Needs full client-profile params (DVB); transient 5xx handling | Plex transcode | `HLSManifestEnricherLoggingTests` (logging only) | Medium |
| HDR / HDR10 | Live via VideoToolbox + `DisplayCriteriaManager` Match-Content | Correctness is display-dependent | `AVDisplayManager` | None (device-only) | Low (until device) |
| HDR10+ | Not separately handled (treated as HDR10 base layer) | No dynamic-metadata-specific path | VideoToolbox | None | Low |
| Dolby Vision (P5/P8.1) | Live, native VideoToolbox | — | VideoToolbox | None (device-only) | Low (until device) |
| Dolby Vision (P7 MEL / P8.6) | Live via RPU rewrite → P8.1 | RPlayer-only; remux often unviable | `HEVCNALParser`, `LibdoviWrapper` | None (device-only) | Low (until device) |
| Dolby Atmos | Passthrough (E-AC-3 JOC) where the chain allows | Depends on route + receiver; not verified | Renderer / receiver | None (device-only) | Low (until device) |
| TrueHD | RPlayer (`FFmpegAudioDecoder` → PCM) | Lossless only outside AVKit/remux | FFmpeg | `RouteAudioPolicyTests` (policy) | Low–Medium |
| DTS-HD | RPlayer decode → PCM | As above | FFmpeg | `RouteAudioPolicyTests` | Low–Medium |
| DTS:X | RPlayer decode → PCM (object audio flattened) | No object rendering | FFmpeg | Partial | Low |
| Subtitles — SRT | Live (`SubtitleParser` → text overlay) | — | SubtitleManager | `SubtitleParserTests` | Medium–High |
| Subtitles — ASS | Live (text overlay; styling subset) | Advanced ASS styling not fully rendered | SubtitleManager | `SubtitleParserTests` | Medium |
| Subtitles — PGS | Live (`FFmpegSubtitleDecoder` → bitmap overlay) | "until next cue" sentinel handling | FFmpeg | Partial | Low–Medium |
| Chapters | Live (`includeChapters=1` + chapter UI + thumbnails in `UniversalPlayerViewModel`) | Polish/validation only | Plex chapters | None | Medium |
| Trailers | Detail "Play Trailer" via Plex Extras live; no silent hero preview | Hero auto-preview not built (Epic 4 scope) | Plex Extras | None | Medium |
| Resume | Live (start offset; seek-on-resume dedupe in pipeline) | Not a single pure tested policy yet (E4-PR4) | Watch-state (Epic 1, consume-only) | `PlaybackStateTests` (state machine) | Low–Medium |
| Live TV | Live (RPlayer per slot; HDHomeRun direct; DVB transcode URL) | DVB needs full transcode params | `MultiStreamViewModel` | None | Low–Medium |

No capability is implemented in this pass; this is an inventory.

---

## Scope 4 — Validation Corpus

The corpus is a **hard pre-merge gate** for any routing change
(`DEBT-E1-PR1-004`). Required minimum:

**Movies**

| Sample | Purpose |
| --- | --- |
| H.264 + AAC MP4 | AVPlayer-direct baseline |
| HEVC 4K + EAC3 | Native HEVC / Match-Content |
| HDR10 | Dynamic-range switching |
| Dolby Vision P5/P8.1 | Native DV |
| Dolby Vision P7 MEL / P8.6 | RPlayer RPU-rewrite path |
| Dolby Atmos (E-AC-3 JOC) | Atmos passthrough |
| DTS-HD MA / TrueHD | Lossless → RPlayer/remux |
| PGS subtitle | Bitmap overlay |
| ASS subtitle | Styled text overlay |
| High-bitrate 4K HEVC/DV over HTTP | `URLSessionAVIOSource` throughput |

**TV**

| Sample | Purpose |
| --- | --- |
| Ongoing series | Up Next / on-deck + status labels |
| Completed series | All-episodes / finale labels |
| Season finale episode | Episode-card finale label + playback |
| Newly aired episode | "New Episode Today/New Episode" + resume |
| Mixed subtitle types in one show | Track-selection parity |

**Live**

| Sample | Purpose |
| --- | --- |
| Live TV (HDHomeRun direct) | Direct stream |
| Live TV (DVB transcode) | Full client-profile transcode URL |
| DVR recording | Recorded-stream playback |

**What Ryan already owns / still needed:** *to be confirmed by Ryan* — this
review cannot enumerate the personal library. Action: Ryan ticks off which rows
above exist in his Plex libraries and flags gaps (especially DV P7/P8.6, TrueHD/
DTS-HD, PGS+ASS, DVB Live) before E4-PR6 (the default flip).

**Which tests require a physical Apple TV:** every HDR/HDR10+/DV/Atmos row, all
Match-Content dynamic-range switching, AirPlay, and any startup/rebuffer numeric
capture. Simulator cannot validate dynamic range, Atmos, or real decode timing.

---

## Scope 5 — Device Validation Requirements

| Environment | Classification | Why |
| --- | --- | --- |
| Apple TV 4K (physical) | **Required** | Only place HDR/DV/Atmos, Match-Content, and real timing are valid |
| HDR-capable display | **Required** | DV/HDR10/HDR10+ dynamic-range correctness |
| Atmos-capable receiver / eARC | **Required** | Atmos passthrough verification |
| Apple TV simulator | **Required** (desk gate) | Build/test, routing-policy unit tests, non-AV logic |
| Non-HDR (SDR) display | **Recommended** | SDR tone-mapping / fallback correctness |
| Variable network conditions (throttle/loss) | **Recommended** | Interruption/recovery ladder (E4-PR5), rebuffer budget |
| AirPlay target | **Recommended** | AirPlay latency compensation path |
| Multiple receivers / TVs | **Optional** | Broader passthrough matrix |

**Status:** physical Apple TV 4K + HDR display + Atmos receiver are **not yet
confirmed available**. This is a hard gate for routing-change merges and for the
Playback parity score above 4.

---

## Scope 6 — Epic 4 Slice Review

Existing decomposition slices, evaluated. Recommended order is unchanged from the
plan, with E4-PR1 scope refined (verify-and-close, per Scope 2).

| Slice | Objective | Risk | Dependency | Blocker | Recommended order |
| --- | --- | --- | --- | --- | --- |
| **E4-PR1** | Playback security: verify/close stream-URL & token redaction; regression tests; finish `print()` scan | **Low** | None (desk/sim) | None once authorised | **1 (first, gating)** |
| **E4-PR2** | Telemetry contract (`os_signpost`/structured: startup, rebuffer, route, fallback reason; no URLs/analytics) | Low–Med | E4-PR1 (clean sinks first); Q2 sink decision | Sink policy unratified | 2 — **DONE 2026-06-02** (`PlaybackTelemetry` safe-by-construction contract + tests + `playback-telemetry-contract.md`; live instrumentation deferred to E4-PR3/PR5 = `DEBT-E4-PR2-001`; sink-policy default chosen, ratification/DSN remain `DEBT-E1-PR2-001`) |
| **E4-PR3** | Pure `PlaybackRoutingPolicy` (AVKit-first selection) + `PlaybackFallbackPolicy`; flag-gated; **no default flip** | Med | E4-PR1/PR2 | AVKit-first not ratified | 3 — **DONE 2026-06-02** (AVKit-first **ratified**; pure routing+fallback policies extracted + tested as faithful mirrors, `avKitFirst` default off, **not wired** → runtime unchanged; live wiring + flip = E4-PR6 / `DEBT-E4-PR3-001`; `playback-routing-policy.md`) |
| **E4-PR4** | Pure `PlaybackResumePolicy` (start offset, seek-on-resume dedupe); per-route verify | Med | E4-PR3 seam | Watch-state must stay consume-only (Epic 1) | 4 — **DONE 2026-06-02** (pure `PlaybackResumePolicy` mirrors prompt/auto-resume/near-end/live/trailer/restart; single seek source; Epic 1 watch-state untouched; not wired → runtime unchanged; wiring = E4-PR6 / `DEBT-E4-PR4-001`; `playback-resume-policy.md`) |
| **E4-PR5** | Deterministic interruption/failure recovery ladder via `.failed`; calm redacted errors | Med–High | E4-PR3/PR4 | Corpus + network conditions | 5 — **DONE 2026-06-02** (pure `PlaybackInterruptionRecoveryPolicy` mirrors background/foreground pause-hold, diagnostics-only audio interruptions, in-place route/auto-flush recovery, remux buffer auto-resume, dead read-loop rebuild, the AirPlay stereo-fallback→abandon ladder, and one-shot fatal fallback delegated to `PlaybackFallbackPolicy`; pure telemetry mapper for `stall`/`recovered`; **not wired** → runtime unchanged; live wiring + emission = E4-PR6 / `DEBT-E4-PR5-001`; `playback-interruption-recovery-policy.md`) |
| **E4-PR5B** | Wire the pure policies into live code (no AVKit flip) | Med | E4-PR2/3/4/5 | Behaviour must be identical | 5B — **DONE 2026-06-02** (4 seams LIVE, behaviour-identical: player selection → `PlaybackRoutingPolicy.player` (avKitFirst off); resume/restart prompt → `PlaybackResumePolicy.decide`; background pause → `PlaybackInterruptionRecoveryPolicy.decide`; first live telemetry → `routeSelected`. Deferred w/ reason: ContentRouter route-family (test-pinned reasoning/URL coupling), `PlaybackFallbackPolicy` **blocked** by a discovered model bug (avKit→noFallback vs live AVPlayer→HLS one-shot fallback — needs PR3 correction), RPlayer async recovery + AirPlay ladder + `routeFellBack`/`stall`/`recovered` emission. Debts reduced not closed: `DEBT-E4-PR2/3/4/5-001`. `PlaybackPolicyIntegrationTests`) |
| **E4-PR6** | **AVKit-first default flip (staged, flag-gated)** | **High** | E4-PR3/PR4/PR5 | **Ratification + corpus + device** | 6 (highest-risk; latest) |
| **E4-PR7** | Subtitle/audio track-selection parity across AVPlayer/RPlayer; documented matrix | Med | E4-PR6 routing | Corpus (PGS/ASS/lossless) | 7 |
| **E4-PR8** | Epic 4 closure: corpus evidence, parity submission, telemetry review, report | Low | All above | Device evidence | 8 (last) |

**Reordering recommendation:** keep the order. The two safe, dependency-light
slices (E4-PR1 security verify/close, then E4-PR2 telemetry contract) front-load
risk reduction and unblock the parity blocker before any routing logic moves. The
**default flip (E4-PR6) stays last among implementation slices** and is the only
one that strictly needs ratification + corpus + device simultaneously. E4-PR3/4/5
build pure, flag-gated, tested seams without changing the default, so they can
proceed on simulator once E4-PR1/PR2 land and AVKit-first is ratified.

---

## Scope 7 — Readiness Decision

### **NOT READY** (for Epic 4 implementation beyond the security slice).

Rationale: of the four standing blockers, only one is effectively retired:

| Blocker | Status |
| --- | --- |
| 1. AVKit-first policy ratified | **Open** — recommended YES, but Project-Owner ratification is outstanding (Scope 1). |
| 2. Stream-URL / Sentry leak scheduled & resolved | **Substantially remediated in code** (Scope 2) but **not formally verified/closed**; E4-PR1 must verify + regression-test + close. Residual `print()` debt (`E0-OBS-003`) remains. |
| 3. Media-validation corpus confirmed | **Open** — contents not yet confirmed against Ryan's library (Scope 4). |
| 4. Physical Apple TV 4K + HDR + Atmos confirmed | **Open** — environment not confirmed (Scope 5). |

Blockers 1, 3, 4 are **Project-Owner / environment decisions this review cannot
clear**. Therefore Epic 4 implementation should not begin broadly.

**Important nuance:** **E4-PR1 (security verify/close) has none of these
dependencies** — no corpus, no device, no ratification. It is the one slice that
can safely proceed the moment Epic 4 is authorised, and doing it first formally
closes the parity blocker. So the precise posture is: *NOT READY for the routing/
flip work; READY to authorise E4-PR1 alone as a desk/simulator slice whenever the
owner chooses.*

---

## Scope 8 — Documentation

- This file (`epic-4-readiness-review.md`) — new.
- `evidence-register.md` — readiness-pass evidence rows added (no closure).
- `debt-register.md` — annotated `E0-OBS-002` status (remediation observed,
  formal close deferred to E4-PR1); no debt closed.

No implementation. No debt falsely closed.

---

## Scope 9 — Validation

`git diff --check` clean. Docs-only; no build required (no code touched).

---

## Final disposition

Epic 4 is **planned and ready to authorise at the slice level (E4-PR1 first)**,
but **NOT READY for full implementation** until the Project Owner: (a) ratifies
AVKit-first-as-default, (b) confirms the media-validation corpus against the
library, and (c) confirms a physical Apple TV 4K + HDR display + Atmos receiver.
The recommended **first implementation slice is E4-PR1 — playback security
verify-and-close** (low risk, no corpus/device/ratification dependency), which
formally retires the `E0-OBS-002/003` parity blocker before any routing work.

*Playback, routes, players, and project settings are unchanged by this review.*
