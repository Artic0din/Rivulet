# E2-PR1 — Performance Evidence

Date: 2026-06-01

Owner: Epic 2 owner

Gate: E0-G07 (Performance — Budget Adherence). Reference:
`Docs/modernization/epic-0/performance-budgets-and-baseline.md`.

## What this PR delivers

The performance **instrumentation foundation**, not a numeric baseline capture
set. E2-PR1 stands up `HomePerformanceTracer` (`os_signpost`, first-party only —
no third-party analytics, no Sentry performance product) so the Epic 0 Home/
launch budgets become measurable with Instruments / Xcode Organizer.

## Instrumented metrics → Epic 0 budgets

| Signpost | Epic 0 metric | Budget | Where emitted |
| --- | --- | --- | --- |
| `LaunchToFirstUsefulScreen` (interval) | PERF-001 cold / PERF-002 warm | ≤ 4.0 s / ≤ 2.5 s | begin: `ContentView.task`; end: `isHomeContentReady == true` |
| `HomeDataLoad` (interval) | supports PERF-001/003 interpretation | — | begin on `.loading` phase / appear-mid-load; end on leaving `.loading` |
| `HomeRenderStateTransition` (event) | render-state transition timing | — | `PlexHomeView` phase `onChange` |
| `HomeHeroReady` (interval) | PERF-003 home hero ready | ≤ 1.5 s after shell | `selectHeroItems()` begin → initial hero ready |
| `HomeCompletion` (event) | home content ready | — | first non-empty `cachedProcessedHubs` |

Subsystem `com.rivulet.app`, category `PerformanceReview` (ADR-005 review-only
taxonomy). Signpost payloads carry only metric IDs and phase names — no tokens,
URLs, or user data (E0-G01 / E0-G08 clean).

## How to capture (first numeric run — follow-up)

Per the Epic 0 measurement protocol, capture with Instruments (os_signpost
instrument) on the validation matrix:

1. Cold launch ×5 (Apple TV simulator + ≥1 physical Apple TV) → PERF-001 median/p95.
2. Warm launch ×5 → PERF-002.
3. Home hero ready ×5 → PERF-003 (note: hero is flag-off by default; interval
   still records preparation time).

Use the Evidence Template in the perf doc, recording build/device/tvOS/network.

## Honest status vs DEBT-E0-008

`DEBT-E0-008` (no formal first-run performance capture set) is **reduced, not
closed**: the capture harness now exists and is wired into the live launch→home
path, but numeric median/p95 captures with Instruments on device are still
outstanding and remain tracked under `DEBT-E0-008`. No budget is claimed met or
breached by this PR.

## Known limitations

- The in-app launch mark is taken at `ContentView.task` start (post process
  launch), not at process spawn. Absolute cold-launch timing uses OS
  process-launch signposts / Instruments per the Epic 0 perf doc. Distinguishing
  cold vs warm in-app is a follow-up refinement.
- Hero readiness is instrumented but the hero is not user-visible by default
  (`showHomeHero == false`); PERF-003 becomes a user-facing budget at E2-PR4.

## Verification

- Instrumentation behavior is unit-tested (`HomePerformanceTracerTests`):
  recorder captures the launch→first-useful-screen and full home-load lifecycle
  event sequences; the production `SignpostHomePerformanceTracer` is asserted
  crash-safe under duplicate/unbalanced lifecycle callbacks.
