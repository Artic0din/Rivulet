# ADR-002: Token Transport and Redaction Policy

**Date**: 2026-05-31  
**Status**: accepted  
**Owner**: Ryan Foyle  
**Review cadence**: Review before Epic 1 closes, before Epic 4 closes, and at Epic 5 release validation

## Context

Rivulet currently handles Plex authentication correctly in some areas but unsafely in others:

- `PlexWatchlistAPI.swift` places `X-Plex-Token` in query parameters and logs those URLs publicly.
- `UniversalPlayerViewModel.swift` sends a raw `stream_url` to Sentry extras.
- `TopShelfExtension/ContentProvider.swift` uses token-bearing image URLs.
- `Docs/AUDIT_FINDINGS_LOCAL.md` flags token-bearing URL logging as a material security issue.

The product depends on Plex account tokens, server tokens, and user-scoped tokens. Those secrets must be usable while remaining absent from logs, crash reports, extension payloads, and human-readable diagnostics.

## Decision

Rivulet will use a header-first token transport policy wherever Plex accepts it, and a mandatory redaction policy for every surface where URLs or request metadata can be emitted.

If a Plex surface technically requires query-string token transport, that path must be:

1. explicitly classified in the network surface inventory
2. isolated behind an adapter
3. sanitized before any logging, crash reporting, or extension distribution

Raw tokens, token-bearing URLs, raw auth headers, and raw stream URLs are forbidden in production diagnostics and extension-facing payloads.

## Alternatives Considered

### Alternative 1: Keep mixed query-string and header transport with ad-hoc masking

- **Pros**: Minimal code churn; fastest short-term path
- **Cons**: Easy to miss leak points; masking quality varies; reviewers cannot reason about safety consistently
- **Why not**: Rejected because current leaks already show that ad-hoc masking is insufficient

### Alternative 2: Require headers only everywhere

- **Pros**: Cleanest mental model; lowest leakage risk
- **Cons**: Some Plex or discover/provider surfaces may still depend on query-string token usage
- **Why not**: Rejected because the repo already integrates unstable Plex provider endpoints that may not support header-only auth

### Alternative 3: Remove all diagnostics touching URLs

- **Pros**: Lowest direct leak risk
- **Cons**: Makes debugging playback, watchlist, and remux problems significantly harder
- **Why not**: Rejected because sanitized route summaries and redacted URLs are sufficient and more useful

## Consequences

### Positive

- Token handling becomes reviewable and testable
- Sentry and log surfaces can retain useful diagnostics without exposing secrets
- Top Shelf and extension boundaries become safer
- Epic 1 and Epic 4 can enforce the same rules instead of inventing local fixes

### Negative

- Some adapters may need extra code to convert from URL-based builders to sanitized structures
- A few Plex provider surfaces may remain awkward until their transport behavior is fully validated
- Review overhead increases because every diagnostic addition must be checked against the policy

### Risks

- A missed emission path could still leak a token if code bypasses the shared sanitization policy
- Over-redaction may remove diagnostics needed to fix route or transcode failures
- Query-token surfaces could remain necessary longer than preferred

Mitigation:

- Centralize redaction helpers
- Add explicit observability review for new fields
- Track all unavoidable query-token surfaces in the inventory and ADR-003 containment model
