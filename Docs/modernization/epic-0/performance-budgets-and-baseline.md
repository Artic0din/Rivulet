# Performance Budgets and Baseline

## Purpose

This document defines the performance metrics, budgets, capture rules, and baseline status for Rivulet modernization work.

## Principles

1. Performance budgets are product requirements.
2. Budgets apply before Epic 5; they are not end-stage cleanup.
3. A regression without evidence is not accepted as “probably fine.”
4. Budget breaches require explanation and owner sign-off.

## Metric Definitions

| Metric ID | Metric | Definition |
| --- | --- | --- |
| PERF-001 | Cold Launch to First Useful Screen | Time from process launch to a visually usable home shell |
| PERF-002 | Warm Launch to First Useful Screen | Time from warm relaunch to usable home shell |
| PERF-003 | Home Hero Ready | Time until hero artwork, title, and primary action are present |
| PERF-004 | Preview First Motion | Time from poster focus to visible preview expansion |
| PERF-005 | Preview Settled | Time from poster focus to stable preview state with metadata |
| PERF-006 | Playback Startup - AVPlayer | Time from play action to first stable frame/audio on AVPlayer routes |
| PERF-007 | Playback Startup - Remux/HLS | Time from play action to first stable frame/audio on remux or HLS routes |
| PERF-008 | Seek Response | Time from seek command to stable resumed playback |
| PERF-009 | Focus Response | Time from navigation input to updated focus state |
| PERF-010 | Image Cache Hit | Time to present cached artwork already on disk or in memory |
| PERF-011 | Browse-to-Playback Memory Growth | Memory delta across extended browse + playback session |

## Target Budgets

| Metric ID | Target | Notes |
| --- | --- | --- |
| PERF-001 | `<= 4.0s` | Apple TV 4K, cold launch on representative LAN |
| PERF-002 | `<= 2.5s` | Warm launch target |
| PERF-003 | `<= 1.5s` after home shell | Hero should not lag far behind home readiness |
| PERF-004 | `<= 150ms` | First visible preview motion |
| PERF-005 | `<= 700ms` | Stable preview with metadata |
| PERF-006 | `<= 1.5s` | AVPlayer direct play target |
| PERF-007 | `<= 2.5s` | Remux or HLS target |
| PERF-008 | `<= 750ms` for local seeks | Network-dependent seeks may exceed, but must be measured |
| PERF-009 | `<= 50ms` | UI focus movement should feel immediate |
| PERF-010 | `<= 100ms` | Cached poster/hub art target |
| PERF-011 | No unbounded growth | Extended session must not show persistent growth without release |

## Measurement Protocol

Each performance run must use the same calculation model unless a work package records an explicit exception.

| Metric ID | Measurement Method | Sample Size | Median / P95 Calculation | Tooling | Pass / Fail Interpretation |
| --- | --- | --- | --- | --- | --- |
| PERF-001 | Mark process launch and first visually usable home shell | Minimum 5 cold launches | Sort run durations; median is middle value, p95 is nearest-rank ceiling of `0.95 * n` | `os_signpost`, unified logging timestamps, Xcode Organizer or Instruments where available | Pass when median and p95 are within budget; fail when either exceeds budget without accepted debt |
| PERF-002 | Mark warm relaunch request and first visually usable home shell | Minimum 5 warm launches | Same nearest-rank method | `os_signpost`, unified logging timestamps | Pass when median and p95 are within budget |
| PERF-003 | Mark home shell visible and hero artwork/title/action ready | Minimum 5 home loads across representative account state | Same nearest-rank method | `os_signpost`, screen recording timestamp review when signposts are absent | Fail when hero readiness exceeds budget or visibly lags enough to affect first impression |
| PERF-004 | Mark poster focus event and first visible preview expansion frame | Minimum 10 focus events across at least 5 items | Median and p95 across all focus events | `os_signpost`, high-frame-rate screen recording when needed | Fail when p95 exceeds budget or motion is visibly delayed |
| PERF-005 | Mark poster focus event and stable preview metadata/artwork state | Minimum 10 focus events across at least 5 items | Median and p95 across all focus events | `os_signpost`, screen recording timestamp review | Fail when preview settles above budget or content appears in unstable stages |
| PERF-006 | Mark play action and first stable frame/audio on AVPlayer direct routes | Minimum 3 runs per relevant media corpus sample | Median and p95 per sample class, then worst-class result controls | `os_signpost`, player state logs, media corpus IDs | Fail when any representative direct-play class exceeds budget without route-specific justification |
| PERF-007 | Mark play action and first stable frame/audio on remux or HLS routes | Minimum 3 runs per relevant media corpus sample | Median and p95 per sample class, then worst-class result controls | `os_signpost`, player state logs, media corpus IDs | Fail when any remux/HLS route exceeds budget without accepted debt |
| PERF-008 | Mark seek command and stable resumed playback | Minimum 5 seeks per tested route | Median and p95 per route | Player state logs, `os_signpost`, screen recording when needed | Fail for local seeks above budget; network-dependent failures require investigation and evidence |
| PERF-009 | Mark remote/navigation input and updated focus state | Minimum 20 focus moves across changed surface | Median and p95 across moves | Focus logs, tvOS simulator/device recording, Instruments if needed | Fail when p95 exceeds budget or visible focus lag occurs |
| PERF-010 | Mark cached artwork request and rendered image | Minimum 20 cached image requests | Median and p95 across cached requests | Image cache logs, `os_signpost` around cache lookup/render | Fail when cached presentation exceeds budget or cache misses are misclassified as hits |
| PERF-011 | Measure memory before browse session, before playback, after playback, and after exit/settle | One 30-minute run per affected browse/playback path, repeated if a regression is suspected | Track peak, final settled memory, and delta; p95 is not required for single soak runs | Instruments Allocations/Leaks, Xcode memory graph, OS memory logs | Fail when memory grows without release after settle, leaks are observed, or user-visible degradation appears |

## Current Baseline Status

As of 2026-05-31, Rivulet does not yet have a structured Epic 0 performance evidence pack. The current baseline is therefore a combination of known risks and required first captures:

- No standardized launch metrics are stored in-repo yet.
- No standardized preview latency captures are stored in-repo yet.
- No standardized playback startup metrics are stored in-repo yet.
- The repo audit identifies Swift 6 concurrency debt, unsafe teardown, and logging debt that can distort runtime performance and stability.
- The audit also records that `URLSessionAVIOSource` is required for high-bitrate 4K HTTP playback and that the read-loop throttle is tuned to tvOS display-layer behavior.

These are real baseline facts; they are not substitute measurements.

## Baseline Capture Requirements

The first formal capture must include:

1. Cold launch on Apple TV simulator
2. Warm launch on Apple TV simulator
3. At least one cold and warm launch on physical Apple TV
4. Preview expansion on Home and Library
5. AVPlayer direct startup using the media validation corpus
6. Remux or HLS startup using the media validation corpus
7. One 30-minute browse -> playback -> exit memory observation

## Capture Conditions

Every performance run must record:

- build configuration
- device or simulator model
- tvOS version
- network type
- media sample ID if playback-related
- route type if playback-related
- whether measurement is cold or warm

## Evidence Template

```markdown
## Performance Run Record

- Metric ID:
- Date:
- Build:
- Device:
- tvOS:
- Network:
- Media sample:
- Route type:
- Run type: cold / warm / repeated
- Median:
- P95:
- Budget:
- Result:
- Notes:
```

## Review Rules

1. A budget breach without explanation is a blocker for the affected work package.
2. A budget breach with explanation may proceed only with explicit debt acceptance and follow-up date.
3. Any performance claim in a PR or review must cite a measured run.
4. Playback route changes must use media-validation-corpus sample IDs in their evidence.

## Escalation

| Failure | Required action |
| --- | --- |
| Launch budget breach | Epic owner investigates and provides before/after evidence; merge blocked until understood |
| Preview budget breach | Epic owner provides trace or measurement; scope may need reduction |
| Playback startup breach | Epic owner validates with corpus sample IDs; Epic 4 owner review required |
| Memory growth issue | Reproduce and document; cannot ship unresolved if user-facing degradation is visible |

## Acceptance Criteria

This document is acceptable when:

1. Metrics and budgets are defined for launch, home, preview, focus, playback, cache, and memory.
2. Capture requirements are explicit and reusable.
3. The absence of formal measurements is recorded honestly as a current baseline fact.
4. Measurement method, sample size, median/p95 calculation, tooling, and pass/fail interpretation are defined for every metric.
5. Reviewers can use the budgets to accept or reject work.
