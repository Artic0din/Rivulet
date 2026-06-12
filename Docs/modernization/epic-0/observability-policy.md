# Observability and Sentry Hygiene Policy

## Purpose

This policy defines how Rivulet records logs, breadcrumbs, crash reports, and diagnostic events during modernization work.

It exists because current repo behavior is inconsistent:

- `print()` is widely used across auth, playback, libraries, and Top Shelf.
- Sentry filtering in `RivuletApp.swift` only drops some cancellation noise.
- `UniversalPlayerViewModel.swift` currently sends a raw `stream_url` to Sentry.
- `PlexWatchlistAPI.swift` logs token-bearing URLs publicly.

## Policy Goals

1. Preserve useful diagnostics.
2. Prevent secret leakage.
3. Make logs and crash events reviewable and comparable.
4. Support Epic 4 playback telemetry without compromising privacy.

## Logging Taxonomy

Use `Logger` with subsystem and category conventions.

### Subsystems

- `com.rivulet.app` for main-app logging
- `com.gstudios.rivulet.TopShelfExtension` for extension logging

### Category Rules

| Category Type | Examples |
| --- | --- |
| Surface | `PlexHome`, `PreviewHost`, `SidebarFocus`, `ContentProvider` |
| Domain | `PlexAuth`, `PlexNetwork`, `Playback`, `Cache`, `DeepLink` |
| Review-only | `SecurityReview`, `PerformanceReview`, `AccessibilityReview` |

### Severity Rules

| Level | When to use |
| --- | --- |
| `debug` | Local development diagnostics not intended for production review |
| `info` | Important state changes safe for retained diagnostics |
| `notice` | Significant non-error operational events |
| `error` | Failures requiring investigation |
| `fault` | Severe failures that may indicate corruption or user-visible breakdown |

## Forbidden Fields

The following fields must never be emitted raw to logs, breadcrumbs, or crash extras:

- `X-Plex-Token`
- token-bearing query strings
- raw `stream_url`
- raw server URL when it exposes private network structure and is not required
- PIN values
- full auth headers
- full extension cache payloads when they contain sensitive URLs

## Allowed Diagnostic Fields

These are allowed when needed and when not joined to secrets:

- route type (`avPlayerDirect`, `localRemux`, `hls`, `directPlay`)
- media type (`movie`, `show`, `episode`)
- rating key
- playback start offset
- failure code or error domain
- session identifier
- selected audio/subtitle track identifiers when they are not secrets

## Redaction Rules

1. Any URL logged or reported must be sanitized before emission.
2. Sanitization must remove secret-bearing query items, not merely mask them visually in the UI.
3. If a URL cannot be safely sanitized and still be useful, replace it with a route summary.
4. Token-bearing URLs must not be forwarded into Top Shelf or public CDN surfaces.

### Required Example

Allowed:

```text
Playback route failed route=localRemux mediaType=movie ratingKey=12345
```

Forbidden:

```text
Playback failed url=https://server:32400/video/...&X-Plex-Token=abcd1234
```

## Sentry Rules

### Allowed Tags

- `component`
- `player_type`
- `route_type`
- `media_type`
- `build_channel`

### Allowed Extras

- `rating_key`
- `start_offset`
- `session_id`
- `error_context` if it contains no secrets

### Disallowed Extras

- `stream_url`
- raw request URL if it may contain query tokens
- raw headers
- raw server URL if it adds no essential diagnostic value

### Current Configuration Baseline

As of Epic 1 PR 3:

- Sentry startup is compiled only for non-Debug builds in `Rivulet/RivuletApp.swift`.
- The DSN is provided by ignored local file `Rivulet/Config/Secrets.swift` via `Secrets.sentryDSN`.
- The tracked `Rivulet/Config/Secrets.swift.template` contains only the placeholder `YOUR_SENTRY_DSN_HERE`.
- This workspace does not contain a local `Secrets.swift`, so current Debug validation does not report to Sentry.
- A copied Release DSN could report to an inherited project unless Project Owner confirms Sentry project ownership or explicitly disables Release startup before release validation.
- PR 2 disables Sentry automatic failed-request capture, automatic network breadcrumbs, and automatic network tracking to avoid SDK-captured raw URL/header leakage.
- PR 2 adds `beforeSend` sanitization for event tags, extras, contexts, breadcrumbs, exceptions, messages, request URLs, query strings, and request headers.
- PR 3 privacy baseline declares crash, performance, and other diagnostic data in the main app privacy manifest because Release Sentry can submit diagnostics when a DSN is configured.

### Sentry Privacy Ownership Requirement

Sentry is not production-acceptable solely because a privacy manifest exists. Before release validation or any Epic 1 release-candidate build:

1. Project Owner must confirm that `Secrets.sentryDSN` points to a Rivulet-owned Sentry project, or explicitly disable Release Sentry startup.
2. Privacy reviewer must confirm that the App Store privacy disclosure matches the enabled Sentry data types.
3. Observability reviewer must confirm PR 2 redaction and `beforeSend` sanitization still cover changed events, extras, contexts, breadcrumbs, request data, and headers.
4. Any new Sentry field that can contain Plex tokens, server URLs, media asset URLs, PINs, credentials, profile identifiers, stream URLs, or Top Shelf payload data blocks merge until redacted or removed.

### Shared Redaction Utility

Application code must use `SensitiveDataRedactor` for any diagnostic field that may contain a token, credential, PIN, auth header, query-token URL, stream URL, media asset URL, Discover/provider URL, PMS transcode URL, playback decision URL, or Top Shelf image URL.

The redactor supports:

- raw strings
- `URL`
- `URLComponents`
- string header dictionaries
- nested metadata dictionaries and arrays used by Sentry extras, event contexts, or breadcrumb data

## Review Requirements

Any change that adds or modifies:

- a log statement
- a breadcrumb
- a Sentry tag
- a Sentry extra
- a crash event payload

must include an observability review note confirming:

1. field contents
2. redaction status
3. sink
4. reviewer decision

## Baseline Remediation Targets

These current surfaces are explicitly in scope for first-pass remediation:

1. `Rivulet/Services/Plex/PlexWatchlistAPI.swift`
2. `Rivulet/Views/Player/UniversalPlayerViewModel.swift`
3. `TopShelfExtension/ContentProvider.swift`
4. `TopShelfExtension/TopShelfCache.swift`
5. `Rivulet/RivuletApp.swift`
6. `Rivulet/Services/Plex/PlexNetworkManager.swift`

## Evidence Template

```markdown
## Observability Review Record

- Date:
- Owner:
- Reviewer:
- Surface:
- Event or log:
- Fields emitted:
- Sanitization applied:
- Sink:
- Result:
- Follow-up:
```

## Escalation

- Any forbidden field in a production sink is a blocker.
- Any unreviewed new crash field is a blocker.
- Any unresolved ambiguity about whether a field contains a secret must be treated as a blocker until clarified.

## Playback telemetry (Epic 4)

Playback telemetry is governed by the typed `PlaybackTelemetry` contract
(`Docs/modernization/epic-4/playback-telemetry-contract.md`,
`Rivulet/Services/Plex/Playback/PlaybackTelemetry.swift`), which implements this
policy for playback: a fixed allow-list of non-sensitive fields, no `URL`/dict in
the public API, boundary redaction, and signpost-event-name-only + redacted
Sentry breadcrumb sinks. New playback telemetry MUST be emitted through it, not
through ad-hoc breadcrumbs/extras or `print`.

## Acceptance Criteria

This policy is acceptable when:

1. Allowed and forbidden fields are explicit.
2. Logging taxonomy is specific enough to review new diagnostics.
3. Sentry rules are concrete enough to reject unsafe crash metadata.
4. Current high-risk repo surfaces are named directly.
