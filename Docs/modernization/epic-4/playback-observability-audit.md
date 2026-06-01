# Playback Observability Audit (E4-PR1)

Date: 2026-06-01
Scope: security/observability verification of all playback diagnostics. No
playback routing, AVKit/RPlayer defaults, subtitles, chapters, resume, or UX
changed. One log-line redaction + regression tests only.
Sources audited: `Services/Plex/Playback/**`, `Views/Player/**`,
`Views/LiveTV/**`.

---

## 1. Inventory

395 diagnostic call-sites across `Services/Plex/Playback/**` (plus the player
view model and Live TV). The dominant pattern is **`playerDebugLog`** — a
`#if DEBUG` wrapper over `print` (`PlayerDebugLog.swift`); it is a **no-op in
release** but **executes in DEBUG / simulator**, so a DEBUG-only print is still a
real console exposure on simulator (same threat model as the HLS manifest leak
fixed in `SEC-HLS-*`).

Surface types observed: `playerDebugLog`/`print`, `SentrySDK.capture`,
`SentrySDK.addBreadcrumb`, `scope.setExtra`, `scope.setTag`. The security-relevant
subset is only those that interpolate a URL, token, header, or full path.

Heaviest files (call-site counts): `DirectPlayPipeline` (95), `SampleBufferRenderer`
(43), `RivuletPlayer` (26), `FFmpegDemuxer` (26), `FFmpegAudioDecoder` (23),
remux/HLS (~20 each). The vast majority are codec/timing/state diagnostics with no
URL or token.

---

## 2. Stream-URL / token exposure verification

Every URL/token-interpolating diagnostic across the three trees, classified
(SAFE / REDACTED / RISK / UNKNOWN). Nothing assumed safe — each was inspected.

| Location | Diagnostic | Classification | Proof |
| --- | --- | --- | --- |
| `FFmpegDemuxer.swift:235` | `playerDebugLog(... \(url.absoluteString))` | **RISK → FIXED** | `absoluteString` carries `?X-Plex-Token=…` + host; printed in DEBUG/simulator. **Remediated:** now logs `url.lastPathComponent` (asset name only). |
| `RivuletPlayer.swift` 165/174/207/213/217 | `... \(url.lastPathComponent)` | SAFE | `lastPathComponent` excludes query (token) and host. |
| `DirectPlayPipeline.swift:344` | `... \(url.lastPathComponent)` | SAFE | As above. |
| `HLSManifestEnricher.swift:118` | `... manifestDiagnosticSummary(patched)` | REDACTED | Counts only (lines/variants/media/iFrame/uriRefs); `SEC-HLS-001`. |
| `UniversalPlayerViewModel.swift:1591` | `... manifestDiagnosticSummary(kfManifest)` | REDACTED | Same summary; `SEC-HLS-002`. |
| `UniversalPlayerViewModel.swift:1183` (error capture) | `setExtra` title/type/ratingKey/start_offset | SAFE | No URL/token; the original `E0-OBS-002` raw `stream_url` extra is gone. |
| `HLSSegmentFetcher.swift` 91-95 / 239-243 | `setExtra` `variant_url`/`master_url` = `redactedURLValue`; `host`; counts | REDACTED | Uses `SensitiveDataRedactor.redactedURLValue`; host only. |
| `HLSSegmentFetcher.swift` 185-189 | `setExtra` `host`, `path` | SAFE | Host + path (no query/token). |
| `HLSPipeline.swift:375` | `setExtra` `stream_host` = `streamURL?.host` | SAFE | Host only. |
| `HLSPipeline.swift:131` / `DirectPlayPipeline.swift:550` / `UPVM:1019` | breadcrumb `.message` static strings | SAFE | "HLS Pipeline Load" / "DirectPlay Load" / "Playback selection (\<reason\>)". |
| `MultiStreamViewModel.swift` 246-248 / 294 / 520 / 540 | `*_scheme`/`*_host`/`*_path`; `stream_url` = `redactedURLValue` | REDACTED | Components only; full URL redacted. |
| `MultiStreamViewModel.swift` 303/546 | `print(... \(channel.name) id: \(channel.id))` | SAFE | Channel name/id, not a URL/token. |
| `URLSessionAVIOSource.swift:656` | `... error.localizedDescription` | SAFE | `URLError.localizedDescription` is the human message; does not embed the URL string. |
| `FFmpegDemuxer.swift:256`, `FFmpegRemuxSession.swift:207/522` | `url.absoluteString` as `avformat_open_input` argument | SAFE | Function argument, **not a log sink**. |
| `FFmpegDemuxer.swift:237` | `headers` → `av_dict_set` | SAFE | Auth header set into FFmpeg options (the real request), not logged. |

Repo-wide search for any `setExtra` / `addBreadcrumb` carrying a raw URL /
`absoluteString` / `stream_url` value: **empty**. After the `FFmpegDemuxer` fix,
no `print`/`playerDebugLog`/`os_log`/Sentry sink in the audited trees emits a raw
token, full stream URL, or token-bearing query.

---

## 3. Sentry verification

All playback Sentry usage reviewed. Metadata sent on playback capture/breadcrumb:
component/player-type **tags**; **extras** limited to `media_title`,
`media_type`, `rating_key`, `start_offset`, segment/variant **counts**, `host`,
`path`, `segment_index`, and `redactedURLValue` for any URL-typed key. No token,
no full stream URL, no manifest body. `title`/`ratingKey` usage is appropriate
(non-secret identifiers already present in metadata). Breadcrumb messages are
static. **No Sentry risk found.**

DSN ownership remains `DEBT-E1-PR2-001`; the telemetry-sink policy (signpost-only
vs Sentry breadcrumbs) is an open Project-Owner question (architecture §6 Q2) and
is E4-PR2 scope, not this slice.

---

## 4. Residual print() migration

`playerDebugLog`/`print` is widespread (≈360 of the 395 sites). Targeted audit of
every URL/token-interpolating site found exactly one leak (`FFmpegDemuxer:235`,
now fixed). The remaining sites log codec ids, timestamps, byte/rate counters,
state transitions, and `lastPathComponent`/`host` — none carry a token or full
URL.

Per the slice mandate ("do not perform a broad logging rewrite; only fix issues
tied to token/URL/observability risk"), no other `print` was changed. The broad
migration of `playerDebugLog`/`print` → a structured, redaction-aware logger is
**not a security risk** but remains observability hygiene debt
(`DEBT-E1-PR1-006` / `KF-E0-004`). Documented, not auto-refactored.

---

## 5. Safe paths

- All `lastPathComponent`-based load logs (`RivuletPlayer`, `DirectPlayPipeline`,
  now `FFmpegDemuxer`).
- All breadcrumb messages (static strings).
- Player error capture extras (title/type/ratingKey/start_offset).
- HLS Sentry extras (host/path/counts).
- `avformat_open_input` URL arguments and the FFmpeg header dict (not log sinks).

## 6. Redacted paths

- HLS manifest diagnostics → `manifestDiagnosticSummary` (counts only).
- HLS `variant_url`/`master_url` and Live TV `stream_url` → `redactedURLValue`.
- Live TV URL component extras (`scheme`/`host`/`path`).
- Error/catch diagnostics on the HLS paths → `SensitiveDataRedactor` (`SEC-HLS-003`).

## 7. Residual risk

- **Security:** none identified in the audited playback trees after the
  `FFmpegDemuxer` fix. (Confidence: high for Sentry sinks and URL/token
  interpolation; the `print` audit was exhaustive for URL/token patterns.)
- **Observability hygiene (non-security):** broad `print`/`playerDebugLog`
  remains un-migrated to structured logging (`DEBT-E1-PR1-006`/`KF-E0-004`).
- **Out of this slice:** telemetry-sink policy (E4-PR2); DSN ownership
  (`DEBT-E1-PR2-001`).

## 8. Debt recommendations

- **`E0-OBS-002` → CLOSE.** The raw `stream_url` Sentry extra is gone; the one
  residual console leak (`FFmpegDemuxer` `absoluteString`) is fixed; regression
  tests (`PlaybackObservabilityTests`) + existing `HLSManifestEnricherLoggingTests`
  / `SensitiveDataRedactorTests` lock the invariants.
- **`E0-OBS-003` → REDUCE (not close).** Its security claims (raw `stream_url`
  extras, token-bearing URL exposure) are verified resolved; the broad `print()`
  migration it also describes remains open as `DEBT-E1-PR1-006`/`KF-E0-004`. Keep
  open for the hygiene portion only.
