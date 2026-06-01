# Epic 1 Closure Report — Plex Platform Modernisation

Date: 2026-06-01

Owner: Epic 1 owner

Recommendation: Close Epic 1 with accepted debt.

## Objective Status

Epic 1 objective: make Plex integration safe, classified, and production-grade.

Status: Complete for Epic 1-owned governance and implementation boundaries. Remaining work is accepted downstream debt, live-fixture validation debt, or release-gate debt tracked by Epic 0 governance.

Exit gate status:

| Gate | Status | Evidence |
| --- | --- | --- |
| No token leaks in changed auth/network/provider diagnostics | Satisfied for changed Epic 1 surfaces | `E1-PR2-OBS-001`, `E1-PR4-SEC-001`, `E1-PR6-SCAN-001`, `E1-PR7-SCAN-001`, `E1-PR8-SEC-001`, `E1-PR10-SCAN-001` |
| No undocumented endpoint usage without containment | Satisfied for known Epic 1 surfaces | `security-network-surface-inventory.csv`, `E1-PR1-SCAN-001`, `E1-PR5-CONTAIN-001`, `E1-PR8-CONTAIN-001`, `E1-PR9-BOUNDARY-001`, `E1-PR10-BOUNDARY-001` |
| All Plex integration paths classified and owned | Satisfied with accepted debt | `security-network-surface-inventory.csv`, `E1-PR10-SCAN-001` |
| Required regression evidence captured | Satisfied for local automated tests | `E1-PR10-BUILD-001` through `E1-PR10-TEST-012` |
| Live Plex UAT | Not satisfied; accepted debt | `DEBT-E1-PR1-004` |

## Work Completed

PR 1 through PR 7 were previously accepted locally. They established baseline evidence, redaction hygiene, privacy manifests, credential lifecycle correctness, header-first token transport for locally verifiable core APIs, Plex Home identity boundaries, and stable multi-server selection.

PR 8 completed Discover/watchlist containment:

- Isolated `discover.provider.plex.tv` and `metadata.provider.plex.tv` behind `PlexWatchlistAPI` and `PlexWatchlistProviderBoundary`.
- Added provider failure redaction and recoverable watchlist failure handling.
- Proved account-token usage is distinct from selected server token and Home user token.
- Updated endpoint inventory and debt state for Discover/provider containment.

PR 9 completed watch-state and timeline ownership:

- Added `PlexWatchStateRequestFactory` for PMS timeline, scrobble, and unscrobble requests.
- Centralized state-write token transport as header-token-only for covered state-write requests.
- Preserved playback reporter legacy GET behavior pending Epic 4 playback semantics validation.
- Updated endpoint inventory and debt state for PMS state-write ownership.

PR 10 completed provider abstraction closure:

- Added `PlexProviderBoundaryPolicy` to document provider endpoint and credential ownership.
- Replaced the unused direct `PlexProvider.watchlistAPI` field with injected `PlexWatchlistManaging` read boundary.
- Confirmed `PlexProvider` reads watchlist membership through the account-token-owned `PlexWatchlistService` boundary.
- Kept ref-only provider watchlist writes explicitly unsupported to avoid selected-server-token misuse and incomplete optimistic cache entries.
- Added provider-boundary tests and closure evidence.

## Files Changed By PR

PR 8 — Discover and Watchlist Containment:

- `Docs/modernization/epic-0/debt-register.md`
- `Docs/modernization/epic-0/evidence-register.md`
- `Docs/modernization/epic-0/security-network-surface-inventory.csv`
- `Rivulet/Services/Plex/PlexWatchlistAPI.swift`
- `RivuletTests/Unit/PlexWatchlistAPIContainmentTests.swift`
- `RivuletTests/Unit/PlexWatchlistServiceTests.swift`

PR 9 — Watch State and Timeline Ownership Boundary:

- `Docs/modernization/epic-0/debt-register.md`
- `Docs/modernization/epic-0/evidence-register.md`
- `Docs/modernization/epic-0/security-network-surface-inventory.csv`
- `Rivulet/Services/Plex/Playback/PlexProgressReporter.swift`
- `Rivulet/Services/Plex/PlexNetworkManager.swift`
- `Rivulet/Services/Plex/PlexWatchStateRequestFactory.swift`
- `RivuletTests/Unit/Services/PlexNetworkManagerURLTests.swift`

PR 10 — Provider Abstraction Completion and Closure Evidence:

- `Docs/modernization/epic-0/debt-register.md`
- `Docs/modernization/epic-0/evidence-register.md`
- `Docs/modernization/epic-0/security-network-surface-inventory.csv`
- `Docs/modernization/epic-1/epic-1-closure-report.md`
- `Rivulet/Services/MediaProvider/MediaProviderRegistry.swift`
- `Rivulet/Services/MediaProvider/Plex/PlexProvider.swift`
- `Rivulet/Services/MediaProvider/Plex/PlexProviderBoundaryPolicy.swift`
- `Rivulet/Services/Plex/PlexWatchlistService.swift`
- `RivuletTests/Unit/PlexProviderBoundaryTests.swift`

## Evidence IDs

PR 8 evidence:

- `E1-PR8-AUDIT-001`
- `E1-PR8-CONTAIN-001`
- `E1-PR8-TEST-001`
- `E1-PR8-TEST-002`
- `E1-PR8-SEC-001`
- `E1-PR8-SCAN-001`

PR 9 evidence:

- `E1-PR9-AUDIT-001`
- `E1-PR9-TEST-RED-001`
- `E1-PR9-BOUNDARY-001`
- `E1-PR9-TEST-001`
- `E1-PR9-SEC-001`
- `E1-PR9-SCAN-001`
- `E1-PR9-BUILD-001`
- `E1-PR9-BUILD-002`
- `E1-PR9-TEST-002` through `E1-PR9-TEST-010`

PR 10 evidence:

- `E1-PR10-AUDIT-001`
- `E1-PR10-TEST-RED-001`
- `E1-PR10-BOUNDARY-001`
- `E1-PR10-TEST-FIX-001`
- `E1-PR10-TEST-001`
- `E1-PR10-SCAN-001`
- `E1-PR10-BUILD-001`
- `E1-PR10-BUILD-002`
- `E1-PR10-TEST-INFRA-001`
- `E1-PR10-TEST-002` through `E1-PR10-TEST-012`

## Debt Status

Closed or reduced:

- `DEBT-E1-PR1-002`: resolved for Epic 1 Discover/provider containment. Query-token and live-evidence follow-up remains under separate debt.
- `DEBT-E0-002`: reduced by PR 5, PR 8, and PR 9 but remains open for retained token-bearing media/playback/Top Shelf/Siri/provider paths.
- `DEBT-E0-004` and `DEBT-E1-PR1-006`: reduced for changed Epic 1 diagnostics but remain open for broad logging/Sentry hygiene.

Remaining accepted or inherited debt:

- `DEBT-E0-001`: app-wide ATS/local-network trust policy remains open.
- `DEBT-E0-002`: retained token-bearing URL paths remain open where downstream platform consumers or playback behavior require separate validation.
- `DEBT-E0-004`: broad observability/logging migration remains open.
- `DEBT-E1-PR1-001`: remaining token-bearing URL construction is classified but not eliminated.
- `DEBT-E1-PR1-003`: legacy Plex fallback endpoints are contained but not retired.
- `DEBT-E1-PR1-004`: live Plex fixture coverage is unavailable.
- `DEBT-E1-PR1-005`: ATS/trust policy remains open.
- `DEBT-E1-PR1-006`: sensitive observability surfaces remain outside changed Epic 1 paths.
- `DEBT-E1-PR2-001`: Sentry DSN ownership remains open.
- `DEBT-E1-PR3-001`: local-network privacy description / Bonjour decision remains open.
- `DEBT-E1-PR10-001`: ref-only provider watchlist write contract remains downstream Epic 3 debt.

## Platform Status

Endpoint ownership status:

- Known plex.tv, PMS, Discover/provider, Top Shelf, Sentry, local-network, trust, media asset, playback, Siri/search, and third-party metadata surfaces are classified in `security-network-surface-inventory.csv`.
- Official plex.tv/PMS core API surfaces are owned by Plex auth/resources/home/browse/hub/state-write adapters.
- Discover/provider surfaces are owned by `PlexWatchlistAPI`, `PlexWatchlistProviderBoundary`, and `PlexWatchlistService`.
- Playback/media asset/Top Shelf/Siri token-bearing handoffs are classified and explicitly downstream-owned.

Token transport status:

- Core locally verifiable plex.tv and PMS API calls use header-first authentication.
- PMS timeline/scrobble/unscrobble state writes use header-carried tokens through `PlexWatchStateRequestFactory`.
- Query-token paths remain for Discover/provider APIs, media asset URLs, playback/transcode paths, Top Shelf image handoff, and Siri/search image handoff where behavior cannot be safely changed without downstream validation.

Auth and credential lifecycle status:

- PIN auth, credential replacement, logout clearing, stale/invalid credential handling, selected server token, Home user token, and account token boundaries are explicit and test-covered.

Plex Home identity status:

- Home profile switch, protected user PIN handling, remembered PIN clearing, and Home user token separation are explicit and test-covered.

Multi-server status:

- Server selection uses stable machine identifiers where available, deterministic URL fallback where required, and avoids duplicate display-name matching as a stable identity key.

Discover/watchlist containment status:

- Provider endpoints are isolated behind account-token-owned boundaries.
- Provider failures are recoverable and secret-safe.
- Core PMS browsing, Home, auth, server selection, and playback are not dependent on provider success.

Watch-state and timeline ownership status:

- PMS state-write request construction is centralized for timeline, scrobble, and unscrobble.
- Playback-side reporter method semantics are explicitly retained for Epic 4 validation.

Provider abstraction status:

- `PlexProvider` owns selected-server-token PMS browse/detail/home/playback-resolution/state-write adapter calls.
- Watchlist reads delegate to the account-token-owned `PlexWatchlistService` boundary.
- Ref-only provider watchlist writes remain intentionally disabled and tracked as downstream Epic 3 debt.

## Tests Run

Validation commands:

```bash
git diff --check
xcodebuild -quiet -scheme Rivulet -destination 'platform=tvOS Simulator,id=F8288707-280A-4C5F-94AA-24B706E66909' build
xcodebuild -quiet test -scheme Rivulet -destination 'platform=tvOS Simulator,id=F8288707-280A-4C5F-94AA-24B706E66909' -only-testing:RivuletTests/CredentialRegistryTests
xcodebuild -quiet test -scheme Rivulet -destination 'platform=tvOS Simulator,id=F8288707-280A-4C5F-94AA-24B706E66909' -only-testing:RivuletTests/PlexAuthManagerTests
xcodebuild -quiet test -scheme Rivulet -destination 'platform=tvOS Simulator,id=F8288707-280A-4C5F-94AA-24B706E66909' -only-testing:RivuletTests/PlexNetworkManagerURLTests
xcodebuild -quiet test -scheme Rivulet -destination 'platform=tvOS Simulator,id=F8288707-280A-4C5F-94AA-24B706E66909' -only-testing:RivuletTests/PlexWatchlistServiceTests
xcodebuild -quiet test -scheme Rivulet -destination 'platform=tvOS Simulator,id=F8288707-280A-4C5F-94AA-24B706E66909' -only-testing:RivuletTests/PlexWatchlistAPIContainmentTests
xcodebuild -quiet test -scheme Rivulet -destination 'platform=tvOS Simulator,id=F8288707-280A-4C5F-94AA-24B706E66909' -only-testing:RivuletTests/SensitiveDataRedactorTests
xcodebuild -quiet test -scheme Rivulet -destination 'platform=tvOS Simulator,id=F8288707-280A-4C5F-94AA-24B706E66909' -only-testing:RivuletTests/PlexHomeIdentityTests
xcodebuild -quiet test -scheme Rivulet -destination 'platform=tvOS Simulator,id=F8288707-280A-4C5F-94AA-24B706E66909' -only-testing:RivuletTests/PlexServerSelectionPolicyTests
xcodebuild -quiet test -scheme Rivulet -destination 'platform=tvOS Simulator,id=F8288707-280A-4C5F-94AA-24B706E66909' -only-testing:RivuletTests/PlexProviderBoundaryTests
xcodebuild -quiet test -scheme Rivulet -destination 'platform=tvOS Simulator,id=F8288707-280A-4C5F-94AA-24B706E66909' -only-testing:RivuletTests/HomeComposerTests
xcodebuild -quiet test -scheme Rivulet -destination 'platform=tvOS Simulator,id=F8288707-280A-4C5F-94AA-24B706E66909' -only-testing:RivuletTests/TMDBMediaMapperTests
```

All final validation commands passed. Initial name-based simulator validation failed before test execution because FrontBoard did not recognize the app bundle; the tests were rerun successfully against explicit simulator UDID `F8288707-280A-4C5F-94AA-24B706E66909`.

## UAT Still Required

- Live Plex account/server fixture covering PIN auth, server discovery, selected server reload, and logout.
- Live Plex Home fixture covering profile switch, protected user PIN, failed switch rollback, and Home user token behavior.
- Live multi-server fixture covering duplicate display names, local/remote/relay ordering, and persisted machine identifiers.
- Live Discover/watchlist fixture covering provider fetch, add/remove, metadata match failure, and provider outage degradation.
- Live PMS state-write fixture covering timeline, scrobble, and unscrobble behavior.
- ATS/local-network on-device validation.
- Sentry release-project ownership review.

## Known Limitations

- App-wide ATS/local-network trust policy remains open.
- Sentry DSN ownership remains project-owner/release-gate debt.
- Query-token media asset, playback, Top Shelf image, and Siri/search image handoffs remain classified and contained but not eliminated.
- Legacy Plex fallback endpoints remain contained with retirement triggers but are not removed.
- `MediaProvider` ref-only watchlist writes remain intentionally unsupported until Epic 3 supplies a metadata-bearing write contract.
- Live Plex fixture coverage is not available in the local environment.

## Open Risks

- Live Plex behavior may differ from local request-construction tests for Discover/provider and PMS state-write endpoints.
- Retained query-token handoffs continue to require strict redaction discipline until downstream epics replace or contain them further.
- Release builds can still report to an inherited Sentry project if a fork supplies an inherited local DSN.
- tvOS simulator launch instability can produce false test failures; explicit simulator UDID was required for final PR 10 validation.

## Recommendation

Close Epic 1 with accepted debt.

Rationale: Epic 1-owned auth, credential, token-transport, endpoint classification, provider containment, watch-state, multi-server, Plex Home, and provider-abstraction responsibilities are implemented or formally contained with reviewable evidence. Remaining items are either downstream epic-owned, live-UAT dependent, or release-gate debt already tracked by Epic 0 governance.
