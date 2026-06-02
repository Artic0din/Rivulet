# Playback Interruption & Recovery Policy (E4-PR5)

Date: 2026-06-02
Status: pure policy extracted + tested + documented. Mirrors current
interruption / recovery behaviour exactly and is **not wired** into the live
pipeline → runtime behaviour is unchanged. Watch-state (Epic 1) untouched.
Implementation: `Rivulet/Services/Plex/Playback/Pipeline/PlaybackInterruptionRecoveryPolicy.swift`.
Tests: `RivuletTests/Unit/Playback/PlaybackInterruptionRecoveryPolicyTests.swift`.

---

## 1. Current interruption / recovery behaviour (audited)

No behaviour was changed during the audit. Sources and their handling today:

| Source | Where | Current behaviour |
|--------|-------|-------------------|
| App backgrounded | `UPVM.observeAppLifecycle` (`didEnterBackground`) | If `playbackState == .playing` → set `pausedDueToAppInactive`, `pause()`. Does **not** fire for the tvOS Control Center overlay. |
| App foregrounded | `UPVM.observeAppLifecycle` (`didBecomeActive`) | Clears `pausedDueToAppInactive`; **stays paused** — the user resumes manually. No auto-resume. |
| Audio-session interruption (began/ended) | `AudioRouteDiagnostics` | **Diagnostics only** — logs the route + `shouldResume`; takes no playback action (tvOS interruptions are rare and the OS owns transport). |
| Audio route change | `RivuletPlayer.handleSystemRouteChange` | Reapply audio policy + `recoverAudioFromRendererEvent` (debounced 0.2 s, single-flight). `AudioRouteDiagnostics` also logs. |
| Audio renderer auto-flush | `RivuletPlayer.handleAudioRendererAutoFlush` | AirPlay transport reset → full recover (after AirPlay-instability gating). |
| Audio output-config change | `RivuletPlayer.handleAudioOutputConfigurationChange` | Recover **only while playing** (`guard isPlaying`). |
| AirPlay instability | `RivuletPlayer.recordAirPlayInstabilityEvent` / `shouldAttemptAirPlayStabilityFallback` | Ladder: stereo-fallback rebuild → hard-unstable abandon → else per-event recover (see §2). |
| Buffer underrun / stall | `UPVM` `timeControlStatus` (`waitingToPlayAtSpecifiedRate`) | Surface `.buffering`. |
| Buffer recovered (remux) | `UPVM` `isPlaybackLikelyToKeepUp` + rate observers | With `automaticallyWaitsToMinimizeStalling=false`, AVPlayer pauses on underrun; when `keepUp && rate==0 && readyToPlay && (paused\|\|buffering)` → `player.play()` (auto-resume). RPlayer refills its own buffers (no keepUp path). |
| Read loop died on resume | `DirectPlayPipeline.resume()` | After a paused seek only a preview frame is shown and the read task exits; `resume()` restarts the read loop with preroll. |
| AVPlayerItem failed / RPlayer pipeline fatal | `UPVM` item-status observer / `handlePipelineError` | One-shot direct-play → HLS fallback at the current time (guarded by `hasAttemptedRivuletHLSFallback`); else `.failed` + calm error. Modelled by `PlaybackFallbackPolicy` (E4-PR3). |
| User retry | `UPVM.retryPlayback()` | User action: reset error + fallback guards, stop, reset stream context, restart. |

Duplicate / timing notes preserved: audio recovery is debounced (0.2 s) and
single-flight; the AirPlay ladder is the only path that *rebuilds* the RPlayer on
the same route; route fallback is one-shot per playback at the current time.

## 2. Extracted policy (`PlaybackInterruptionRecoveryPolicy`)

Pure, `nonisolated`, deterministic, loop-free, player-agnostic. No `PlexMetadata`
import, no Plex call.

`InterruptionInput`: `source` (`InterruptionSource`), `player`
(`PlaybackPlayer`), `phase` (`PlaybackPhase`), `pausedDueToBackground`,
`isRemux`, plus the fatal-path delegation inputs (`attemptedFamily`,
`hlsFallbackAlreadyAttempted`, `hlsRouteAvailable`).

`decide(_:) -> RecoveryDecision` mirrors §1:

1. `appBackgrounded` → `pauseAwaitingUser` while playing, else `noAction`.
2. `appForegrounded` → `pauseAwaitingUser` when `pausedDueToBackground`, else `noAction`.
3. `audioSessionInterruption{Began,Ended}` → `logOnly`.
4. `audioRouteChanged` / `audioRendererAutoFlush` → `recoverAudio`.
5. `audioOutputConfigurationChanged` → `recoverAudio` while playing, else `noAction`.
6. `bufferUnderrun` → `showBuffering`.
7. `bufferRecovered` → `resumeImmediately` when `isRemux` and paused/buffering, else `noAction`.
8. `readLoopDied` → `rebuildPlayer` (same-route read-loop restart with preroll).
9. `userRetry` → `retryPlayback`.
10. `fatalError(category)` → delegated to `PlaybackFallbackPolicy.decide`:
    `.fallback(family)` → `fallbackRoute(family)`; `.stopWithError` / `.noFallback`
    → `showPlaybackError`.

**AirPlay instability ladder** — `airPlayInstabilityDecision(_:)` mirrors
`recordAirPlayInstabilityEvent` / `shouldAttemptAirPlayStabilityFallback`
exactly:

- `canTryStereoFallback` = not already fell back **and** not in flight **and** the
  stereo policy differs from the default.
- If `canTryStereoFallback` **and** (`rendererFailure≥1 \|\| autoFlush≥2 \|\|
  outputRecovery≥2 \|\| total≥3`) → `rebuildPlayer` (reload direct-play in stereo
  at the current time).
- Else if (`autoFlush≥3 \|\| outputRecovery≥3 \|\| rendererFailure≥2 \|\| total≥5`)
  → `abandonRecovery` (report failure).
- Else → `recoverAudio` (per-event recovery proceeds).

## 3. Retry limits & loop-freedom

- **Fatal route fallback** is one-shot (delegated to the already-loop-free
  `PlaybackFallbackPolicy`): at most one hop, then `showPlaybackError`.
- **AirPlay ladder** is monotone in the counts: once the stereo fallback is spent
  (`alreadyFellBackToStereo`), `canTryStereoFallback` is false, so it can only
  escalate to `abandonRecovery` — it can never oscillate back to `rebuildPlayer`.
  A test drives escalating counts and asserts it never rebuilds twice and converges
  to abandon.
- **Dead read-loop rebuild** is guarded upstream by `readTask == nil` (only fires
  when the loop actually exited).
- **Background/foreground** resolve to a single pause/await decision; no retry.

## 4. Telemetry (E4-PR2 contract; emission deferred)

`telemetryEvent(for:context:) -> PlaybackTelemetry.Event?` is a pure mapper:

- `showBuffering` → `.stall`
- `resumeImmediately` → `.recovered(.recovered)`
- `rebuildPlayer` / `fallbackRoute` → `.recovered(.fellBack)`
- `abandonRecovery` / `showPlaybackError` → `.recovered(.failed)`
- routine (`noAction` / `logOnly` / `pauseAwaitingUser` / `recoverAudio` /
  `retryPlayback`) → `nil`

Only allow-listed `Event` cases are produced — no URL/token can be expressed, and
`SafeContext` values are scrubbed at the sink (a test feeds a token-bearing URL
into a field and asserts the emitted fields carry no `http`/`://`/host/token).
**Live emission is deferred** (consistent with E4-PR2/PR3/PR4): wiring the
`stall`/`recovered` events lands when the recovery seam is integrated, tracked
with `DEBT-E4-PR2-001` and `DEBT-E4-PR5-001`.

## 5. Behaviour preservation

The policy reproduces each branch in §1 and is **not wired** into UPVM /
RivuletPlayer / DirectPlayPipeline, so live interruption, buffering,
foreground/background, route-loss, AirPlay and fallback behaviour are unchanged.
Verified by `PlaybackInterruptionRecoveryPolicyTests` (background/foreground,
diagnostics-only interruptions, in-place recovery, remux auto-resume, read-loop
rebuild, the full AirPlay ladder incl. the loop-termination case, one-shot fatal
fallback delegation, and telemetry-safe mapping).

## 6. Epic 1 watch-state boundary

**Untouched.** The policy reads typed interruption inputs and returns a decision;
it writes nothing. No change to `PlexProgressReporter`,
`PlexWatchStateRequestFactory`, the provider contract, timeline reporting, or
watchlist behaviour.

## 7. Live-integrated vs deferred

- **Deferred (E4-PR6, behaviour-preserving):** wiring `decide` /
  `airPlayInstabilityDecision` as the single decision source in UPVM /
  RivuletPlayer / DirectPlayPipeline (behind the same routing-integration flag),
  plus live `stall`/`recovered` emission. Tracked `DEBT-E4-PR5-001`.
- **Not in scope ever for this policy:** watch-state writes (Epic 1); the actual
  audio-policy application, renderer recovery, and pipeline rebuild remain in
  `RivuletPlayer` / `DirectPlayPipeline` (the policy decides *whether*, those
  perform *how*).

## 8. No runtime behaviour change

Confirmed: no playback UX change, no route change, no player change, no
AVKit-first flip, no subtitle/audio/chapter/post-play change, no project-setting
change, no provider-boundary change. Pure extraction + tests + docs.

---

## 9. Live integration (E4-PR5B, 2026-06-02)

**`decide(.appBackgrounded)` is now LIVE** in
`UniversalPlayerViewModel.observeAppLifecycle`: the background observer's
`playbackState == .playing` check is replaced by
`PlaybackInterruptionRecoveryPolicy.decide(InterruptionInput(source: .appBackgrounded, …))`,
pausing iff the result is `.pauseAwaitingUser`. The universal playback state is
mapped to `PlaybackPhase` by a 1:1 helper (`.ready → .loading`), and since the
background decision branches only on `.playing`, the runtime behaviour is
identical — proven by `PlaybackPolicyIntegrationTests.testBackgroundPauseMatchesLegacyPlayingCheck`
across all phases.

**Deferred (still `DEBT-E4-PR5-001`, reduced):**

- **Foreground handler** keeps its trivial flag-clear (the policy's
  `pauseAwaitingUser` == "remain paused", which the handler already achieves by
  not resuming); no behavioural wiring needed.
- **RPlayer route-change / auto-flush / output-config recovery and the AirPlay
  stereo-fallback → abandon ladder** stay in `RivuletPlayer`. These are
  timing-sensitive, debounced, single-flight async paths; routing them through
  the policy risks subtle regressions and must be done with on-device AirPlay
  validation. Left in place; debt open.
- **`stall` / `recovered` live emission** is deferred with the recovery wiring
  (it needs the live recovery seam to fire it), tracked with `DEBT-E4-PR2-001`.
