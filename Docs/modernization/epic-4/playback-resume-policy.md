# Playback Resume Policy (E4-PR4)

Date: 2026-06-02
Status: pure policy extracted + tested + documented. Mirrors current resume
behaviour exactly and is **not wired** into the live pipeline → runtime resume
behaviour is unchanged. Watch-state writes (Epic 1) untouched.
Implementation: `Rivulet/Services/Plex/Playback/Pipeline/PlaybackResumePolicy.swift`.
Tests: `RivuletTests/Unit/Playback/PlaybackResumePolicyTests.swift`.

---

## 1. Current resume behaviour (audited)

- **Offset source:** `MediaItem.userState.viewOffset` (seconds; 0 = not started);
  `PlexMetadata.viewOffset` is ms. The detail view prefers `detail?.item`'s
  fresher offset over `currentItem` for the main item.
- **In-progress:** `MediaItem.isInProgress` = `runtime > 0 && offset > 0 &&
  offset/runtime < 0.98` (≥ 98% = not in progress).
- **Prompt vs auto** (`MediaDetailView.presentPlay`): if the
  `promptResumeOrRestart` setting is ON **and** the item is in progress **and**
  offset > 0 → show the resume/restart prompt (seeded with the offset);
  otherwise launch directly (`launch(false)`).
- **Start-offset computation** (play launch closure): `playFromBeginning ? nil :
  (offset > 0 ? offset : nil)` → passed to `UniversalPlayerViewModel.startOffset`.
- **Seek application:** a single place — `startWithFallback` seeks when
  `startTime > 0` (AVPlayer/remux/RPlayer-HLS); RPlayer direct passes `startTime`
  into `load(route:startTime:)`. No duplicate seek today.
- **Progress reporting:** owned by `PlexProgressReporter` /
  `PlexWatchStateRequestFactory` (Epic 1) — unchanged here.
- **Zero/nil offset:** start at beginning. **Near-end (≥ 98%):** not in progress
  → never prompted; the stored offset is still passed through (the player engine
  clamps), so this slice does **not** special-case near-end at resolution time.
  **Offset > duration:** not clamped at resolution (player clamps).
- **Differences:** Live TV (`MultiStreamViewModel`) and trailers
  (`loadAndPlayTrailer`, offset nil) do not resume; episodes use their own
  offset, the main movie/show item prefers the detail's fresher offset.

## 2. Extracted policy rules (`PlaybackResumePolicy`)

Pure, `nonisolated`, ms-based, no `PlexMetadata` import, no Plex call.

`ResumeInput`: `viewOffsetMs`, `durationMs`, `promptEnabled`, `explicitRestart`,
`isLive`, `isTrailer`.

`decide(_:) -> ResumeDecision`:

1. `isLive || isTrailer` → `.startAtBeginning` (resume ignored).
2. `explicitRestart` → `.startAtBeginning`.
3. `promptEnabled && offset > 0 && isInProgress` → `.prompt(offsetMs)`.
4. else → `offset > 0 ? .resume(offsetMs) : .startAtBeginning`.

Supporting: `isInProgress(viewOffsetMs:durationMs:)` (0.98 threshold mirror);
`resolvePromptChoice(offsetMs:userChoseRestart:)` (restart → beginning, else
resume); `seekOffsetMs(for:)` — the single seek source (nil for beginning/prompt,
offset for resume); `startOffsetMs(playFromBeginning:viewOffsetMs:)` — mirrors the
launch-closure computation.

## 3. Behaviour preservation

The policy reproduces each branch above and is **not wired** into
`MediaDetailView`/UPVM, so live resume behaviour is unchanged. Verified by tests
(prompt on/off, near-end, over-duration, live/trailer, restart, boundary).

## 4. Epic 1 watch-state boundary

**Untouched.** The policy is consume-only: it reads already-resolved offsets as
typed inputs and writes nothing. No change to `PlexProgressReporter`,
`PlexWatchStateRequestFactory`, the provider contract, timeline reporting, or
watchlist behaviour.

## 5. Telemetry

`PlaybackTelemetry` has no `resumeApplied` event today; adding one would touch the
contract, so telemetry emission is **deferred** (consistent with E4-PR2/PR3). A
`resumeApplied` case can be added and emitted when the resume policy is wired
(E4-PR6) — tracked with the other deferred emission under `DEBT-E4-PR2-001`.

## 6. Live-integrated vs deferred

- **Deferred (E4-PR6):** wiring `PlaybackResumePolicy` into the live resolution +
  seek path (behaviour-preserving, behind the same routing-integration flag) and
  any `resumeApplied` telemetry. Tracked `DEBT-E4-PR4-001`.
- **Not in scope ever for this policy:** watch-state writes (Epic 1).

## 7. No runtime behaviour change

Confirmed: no default route change, no playback UX change, no resume-prompt
change, no provider-boundary change. Pure extraction + tests + docs.

---

## 8. Live integration (E4-PR5B, 2026-06-02)

**`PlaybackResumePolicy.decide()` is now LIVE** as the single source for the
resume/restart **prompt** decision in `MediaDetailView.presentPlay`: the old
`promptResumeOrRestart && item.isInProgress && offsetSec > 0` branch is replaced
by `decide(ResumeInput(viewOffsetMs:durationMs:promptEnabled:…))`, prompting iff
the result is `.prompt(offsetMs)` (with `offsetMs` == the old
`Int(offsetSec*1000)` seed). `viewOffset`/`runtime` are seconds derived from
integer-millisecond Plex values, so the ms conversion is lossless and
`isInProgress` is bit-identical to `MediaItem.isInProgress` — proven by
`PlaybackPolicyIntegrationTests` across representative values **and the exact 98%
boundary**. Live TV / trailers never route through `presentPlay`, so those flags
stay false.

**Deferred (still `DEBT-E4-PR4-001`, reduced):** the start-offset *arithmetic*
in the play-launch closure (`playFromBeginning ? nil : (offsetSec>0 ? offsetSec : nil)`)
is kept in seconds and **not** routed through `startOffsetMs`, because the policy
is millisecond-integer and the live value is a full-precision `TimeInterval`; a
round-trip would introduce sub-millisecond drift (a technical, if imperceptible,
behaviour change). It is wired only once the seek path itself moves to
milliseconds (with the routing integration, E4-PR6). Watch-state writes (Epic 1)
remain untouched.
