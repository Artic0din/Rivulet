# Privacy Disclosure Matrix

## Purpose

This matrix records the user, device, server, and playback data touched by Rivulet and defines the disclosure, manifest, and review obligations for each data category.

This document is the baseline for Epic 0 privacy review and must be updated whenever a new data element is introduced or an existing one changes behavior.

## Review Rules

1. Any new data element must be added before merge.
2. Any change to storage, sharing, or retention must be reviewed by the Project Owner.
3. Any item involving crash reporting, extension surfaces, or authentication requires security/privacy review.

## Disclosure Matrix

| Data Element | Source | Purpose | Stored Where | Shared With | Sensitivity | Manifest / Disclosure Impact | Current Repo Finding | Required Control |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Plex account token | Plex auth flow | Authenticate account-level Plex calls | Keychain | Plex services; indirectly used by app code | High | Privacy disclosure required; secrets handling policy required | Tokens are used in query strings in watchlist/discover flows | Header-first transport where supported; no logging; redaction in crash reports |
| Plex server token | Plex server selection and playback | Authenticate server-scoped PMS requests | Keychain | Plex Media Server | High | Privacy disclosure required | Token-bearing URLs are logged in current network/player paths | Same controls as account token |
| Plex Home user token | Home-user switching | User-scoped PMS access | Keychain | Plex Media Server | High | Privacy disclosure required | Credential handling exists; no dedicated disclosure artifact yet | Same controls as server token |
| Plex Home PIN | Local profile switching | Allow PIN-protected user switching | Keychain | Not intentionally shared | High | Privacy disclosure required | PIN storage exists via `KeychainHelper` | Restrict scope, avoid logs, document retention |
| Server URL and connection URI | Server discovery, selection, and playback | Reach the selected Plex server or relay | UserDefaults / app state / requests | Plex, local LAN servers, possibly Sentry if mishandled | Medium | Privacy disclosure required because it may reveal local infrastructure | Connection debugging is currently print-heavy | Minimize retention; forbid raw logging unless redacted |
| Rating key | Deep links, detail navigation, playback restoration | Identify media within Plex | NSUserActivity, deep links, internal state | System search index, app flows | Medium | Disclosure required if indexed/searchable | `NSUserActivity` currently uses ratingKey | Keep values minimal; avoid pairing with secrets |
| Media title and type | UI, search eligibility, crash context | User-facing context and debugging | App state, `NSUserActivity`, possible crash metadata | System search index, Sentry if included | Low to Medium | Disclosure required if sent off-device | Media title is sent to Sentry in current playback error scope | Allow if necessary, but keep to minimal diagnostic set |
| Stream URL | Playback and error handling | Load media stream | Runtime only unless logged | PMS or local remux server; currently also Sentry | High | Privacy disclosure required if reported; forbidden in raw telemetry | `UniversalPlayerViewModel` sends raw `stream_url` to Sentry | Never emit raw; redact or replace with route summary |
| Image URL | Artwork loading, Top Shelf | Load posters and backdrops | Runtime cache and Top Shelf cache | PMS, public CDN, Top Shelf extension | Medium to High | Disclosure required if token-bearing | Top Shelf currently receives token-bearing image URLs | No auth token in extension-facing URLs; prefer public CDN or brokered fetch |
| Watch progress | Resume playback and continue watching | Persist user watch state | SwiftData / server sync | Plex Media Server | Medium | Privacy disclosure required | Core product data, not yet formalized in matrix | Document storage and sync behavior |
| Timeline reporting payload | Playback session sync | Update watch state and progress | Runtime only | Plex Media Server | Medium | Disclosure required | Epic 1 will own correctness; current baseline lacks disclosure artifact | Document fields and transport |
| Search query | Search and discover | Return content results | Runtime only unless later persisted | Plex and metadata providers | Medium | Disclosure required if transmitted off-device | Search surfaces exist but not yet governed by a disclosure record | Do not log raw queries unless explicitly approved |
| Crash event metadata | Sentry | Diagnose failures | Sentry backend | Sentry | Medium to High depending on fields | Privacy manifest and privacy disclosure required | Current setup filters cancellation only; field scrub policy missing | Allowed-field list and scrubbers required |
| App group Top Shelf payload | Main app to extension cache handoff | Populate Top Shelf | App group UserDefaults | Top Shelf extension | Medium | Disclosure required if payload contains identifiers or secrets | Top Shelf cache currently includes image URL and media identifiers | No secrets in cache; minimize payload to required fields |
| TMDB proxy request metadata | Discover metadata and artwork | Resolve third-party metadata | Runtime only | TMDB proxy service | Medium | Privacy disclosure required | Audit identifies unauthenticated proxy risk | Limit fields, document third-party sharing |
| HDHomeRun lineup URL and channel identifiers | Live TV discovery | Fetch tuner lineup | Runtime and local cache | HDHomeRun device / PMS | Medium | Disclosure required | Live TV remains in scope for validation corpus and security inventory | Treat local-network data as private infrastructure |

## Current Privacy Baseline

As of 2026-05-31:

- No `PrivacyInfo.xcprivacy` file exists in the repo.
- Sentry is enabled in non-debug builds and currently filters cancellations but does not define a complete forbidden-field policy.
- `NSUserActivity` indexes `ratingKey` for view/play flows.
- Top Shelf cache and extension image handling need privacy minimization.

## Required Controls

### Required before Epic 1 close

- Token-bearing data paths classified and documented
- Privacy manifest baseline created
- Sentry allowed-field and forbidden-field policy accepted
- Query-string token use documented and reduced where technically possible

### Required before Epic 2 close

- Top Shelf payload minimized and reviewed
- Home and hero data-sharing behavior reflected in disclosure matrix

### Required before Epic 4 close

- Playback telemetry and crash metadata aligned to the allowed-field list
- Stream URL raw disclosure eliminated

## Acceptance Criteria

This matrix is acceptable when:

1. Every sensitive data element currently touched by the repo is listed.
2. Each row has a purpose, storage location, sharing model, and required control.
3. Current baseline risks are linked to real repo findings.
4. Manifest and disclosure implications are explicit enough to review a PR against them.

## Escalation

- Missing row for a new data element: merge blocked.
- Changed sharing or storage behavior without matrix update: merge blocked.
- Unreviewed sensitive crash field: merge blocked.
- Manifest ambiguity: Epic owner must escalate to Project Owner before acceptance.
