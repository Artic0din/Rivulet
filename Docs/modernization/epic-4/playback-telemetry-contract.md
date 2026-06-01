# Playback Telemetry Contract (E4-PR2)

Date: 2026-06-02
Status: contract defined + implemented + tested. Live-event instrumentation is
adopted by the slices that own each event (see §9). No playback routing,
AVKit/RPlayer defaults, subtitle/chapter/resume behaviour, UX, or project setting
changed by this slice.
Implementation: `Rivulet/Services/Plex/Playback/PlaybackTelemetry.swift`.
Tests: `RivuletTests/Unit/Playback/PlaybackTelemetryTests.swift`.

This is the single permitted channel for playback telemetry in Epic 4. It is
**safe by construction**: the public API accepts only typed events with
allow-listed fields — there is no `URL` parameter and no free-form dictionary, so
a token / stream URL / manifest URL / auth header / raw error body cannot be
passed in. Every string value is additionally run through
`SensitiveDataRedactor` at the sink boundary (and any embedded URL is stripped to
`[REDACTED_URL]` before token-redaction), as defense-in-depth for free-text
fields such as `reason`.

---

## 1. Allowed events

Typed `PlaybackTelemetry.Event` cases (the small, high-value Epic-4 set):

| Event | Name emitted | Extra typed fields |
| --- | --- | --- |
| `startupBegan` | `playback.startup.began` | `mode` |
| `startupCompleted` | `playback.startup.completed` | `mode`, `startup_ms` (≥ 0) |
| `startupFailed` | `playback.startup.failed` | `failure` (category) |
| `routeSelected` | `playback.route.selected` | `route`, `reason` (redacted) |
| `routeFellBack` | `playback.route.fellback` | `from`, `to`, `failure` |
| `rebuffer` | `playback.rebuffer` | `rebuffer_count` (≥ 0) |
| `stall` | `playback.stall` | — |
| `recovered` | `playback.recovered` | `recovery` (result) |

Each also carries the allow-listed `SafeContext`.

## 2. Allowed fields

`SafeContext` (the *what is playing* descriptors) → emitted keys:
`media_type`, `rating_key`, `codec`, `container`, `audio`, `subtitle`.
Event-specific keys: `mode`, `startup_ms`, `failure`, `route`, `reason`, `from`,
`to`, `rebuffer_count`, `recovery`.

Typed vocabularies (no raw strings can express a URL/token):
`RouteName` {avPlayerDirect, localRemux, hls, rplayerDirectPlay, unknown};
`PlaybackMode` {directPlay, directStream, transcode, unknown};
`FailureCategory` {startup, network, decode, transcode, demux, unsupported,
unknown}; `RecoveryResult` {recovered, fellBack, failed}.

The complete emitted key allow-list is exactly: `media_type, rating_key, codec,
container, audio, subtitle, mode, startup_ms, failure, route, reason, from, to,
rebuffer_count, recovery`. Tests assert no other key can appear.

## 3. Forbidden fields (cannot be expressed; also scrubbed defensively)

Plex token, token-bearing URL, stream URL, manifest URL, subtitle URL, full
request URL, auth headers, raw manifests, raw error bodies, user-private library
file paths, server local IP (a free-text URL is stripped whole, so scheme/host/IP
do not survive), Sentry DSN, credentials, PINs. None of these has a parameter on
the public API; `reason` (the only free text) is URL-stripped + token-redacted.

## 4. Allowed sinks

- **`os_signpost`** (`OSSignposter`, subsystem `com.rivulet.app`, category
  `PlaybackTelemetry`) — performance timings / event markers. The signpost
  carries **only the typed event name**, never field values.
- **Redacted Sentry breadcrumb** (category `playback.telemetry`) — `data` is the
  allow-listed, redacted field dictionary only.
- **No third-party analytics** beyond the existing Sentry.
- No playback URL/token data may enter any sink (enforced by construction).

## 5. Sentry policy

Breadcrumbs only, allow-listed fields, level `.info`. No `setExtra` of raw URLs;
no event capture from the telemetry layer (error capture stays in the existing,
E4-PR1-verified paths). DSN ownership remains open (`DEBT-E1-PR2-001`).

## 6. Signpost policy

`os_signpost` is the preferred sink for performance (startup duration, rebuffer
timing). Field values are NOT attached to signposts — the event name is the only
payload — so a signpost can never carry a forbidden field.

## 7. Local debug policy

Existing `playerDebugLog` (DEBUG-only `print`) is unchanged by this slice. New
telemetry must not use `print` for structured events — it goes through
`PlaybackTelemetry`. The broad migration of legacy `playerDebugLog`/`print` to a
structured logger remains hygiene debt (`DEBT-E1-PR1-006` / `KF-E0-004`); it was
verified secret-free in E4-PR1 but is not migrated.

## 8. Remaining print() migration debt

Unchanged: ~360 `playerDebugLog`/`print` sites across playback are secret-free
(E4-PR1 audit) but not yet structured. Tracked under `DEBT-E1-PR1-006` /
`KF-E0-004`. This slice does not migrate them.

## 9. How future Epic 4 slices must use the contract

- **All playback telemetry MUST be emitted via `PlaybackTelemetry.emit(_:)`** —
  never a hand-built Sentry breadcrumb/extra or a `print` with interpolated state.
- **E4-PR3 (routing/fallback policies)** adopts `routeSelected` / `routeFellBack`
  at the point the route is a typed value (so `RouteName` maps cleanly, with no
  inference from strings). It also instruments `startupBegan`/`startupCompleted`
  around the load lifecycle.
- **E4-PR5 (interruption/recovery)** adopts `rebuffer` / `stall` / `recovered`.
- If a new safe field is genuinely needed, extend `SafeContext` / a typed
  vocabulary and the allow-list test — never add a free-form dictionary.

Instrumentation was deliberately **deferred** from this slice (Scope 4 "safe or
explicitly deferred"): wiring route/fallback/rebuffer events belongs with the
slices that own those typed values, and avoids premature edits to the
constraint-heavy playback files. The contract is ready for them to call.

Adoption tracking: `DEBT-E4-PR2-001`.
