# ADR-005: Observability and Sentry Hygiene Policy

**Date**: 2026-05-31  
**Status**: accepted  
**Owner**: Ryan Foyle  
**Review cadence**: Review before Epic 4 closes and during Epic 5 release validation

## Context

Rivulet has valuable diagnostics today, but they are inconsistent and sometimes unsafe:

- `RivuletApp.swift` initializes Sentry and filters some canceled request noise.
- `UniversalPlayerViewModel.swift` emits raw `stream_url` to Sentry extras.
- `PlexWatchlistAPI.swift` logs token-bearing URLs publicly.
- `TopShelfCache.swift`, `PlexAuthManager.swift`, `PlexNetworkManager.swift`, and player paths still rely heavily on `print()`.

Playback, discover, auth, and extension work all need diagnostics. The problem is not observability itself; the problem is ungoverned observability.

## Decision

Rivulet will adopt a governed observability model:

- `Logger`-based structured diagnostics are the preferred path
- Sentry tags and extras must use an allow-list
- Raw tokens, raw stream URLs, and raw auth-bearing URLs are forbidden in production sinks
- Every new observability field must be reviewable against one policy document

The allowed diagnostic surface is summarized in `Docs/modernization/epic-0/observability-policy.md`.

## Alternatives Considered

### Alternative 1: Keep existing mixed logging and add small local fixes

- **Pros**: Lowest short-term cost
- **Cons**: Inconsistent review; high chance of future leaks; hard to compare diagnostics across surfaces
- **Why not**: Rejected because the repo already demonstrates unsafe inconsistency

### Alternative 2: Remove most diagnostics to avoid leaks

- **Pros**: Lower leak surface
- **Cons**: Playback and network failures become much harder to debug; Epic 4 telemetry goals become unrealistic
- **Why not**: Rejected because sanitized, governed diagnostics provide better value

### Alternative 3: Keep Sentry unrestricted and rely on reviewer judgment

- **Pros**: Maximum debugging context
- **Cons**: High privacy and security risk; review becomes subjective
- **Why not**: Rejected because some fields are categorically unsafe

## Consequences

### Positive

- Reviewers get a single standard for logs and crash data
- Epic 4 can add telemetry without re-debating basic hygiene
- Security and privacy risk from diagnostics is substantially reduced

### Negative

- Existing logging will need cleanup and migration
- Some previously convenient fields will no longer be allowed
- Reviewers must inspect observability changes deliberately

### Risks

- Overly restrictive diagnostics may slow debugging if route summaries are not good enough
- Teams may bypass the policy with direct `print()` usage if enforcement is weak

Mitigation:

- Publish concrete allowed and forbidden field lists
- Require observability review for new diagnostics
- Prefer route summaries and IDs over raw URLs
