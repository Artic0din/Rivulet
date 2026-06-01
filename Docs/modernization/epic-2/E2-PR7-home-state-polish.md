# E2-PR7 — Home Loading, Empty, Error, and Recovery Polish

Date: 2026-06-01
Owner: Epic 2 owner
Workstream: WS-A (Home Composition & State)
Branch: `codex/epic-2-pr4-canonical-hero`

## Objective

Make Home's non-happy paths feel intentional and premium: calm loading,
actionable empty, recoverable error with deterministic retry focus, and copy
that is user-facing and never leaks secrets/URLs/tokens.

## Audit findings (before)

E2-PR1 already established the shared, accessible state surface
(`ContentStateView` + `RenderState`/`RenderStateResolver`) and wired the
credentialed Home path to it:

- Loading: centered progress + label, combined VoiceOver element, motion-free.
- Empty: "No Content" + Refresh action.
- Error: "Unable to Load" + Try Again, with deterministic initial focus on the
  retry control and an explicit accessibility hint.

So loading/empty/error *structure*, *retry focus*, and *accessibility* were
already polished. The remaining gap was the **error message content**.

Three Home surfaces displayed raw strings verbatim:

1. `homeRenderState` error → `dataStore.hubsError`, set from
   `error.localizedDescription` (`PlexDataStore.swift:453`).
2. Recommendations error → `recommendationsError`, also
   `error.localizedDescription` (`PlexHomeView.swift:662`).
3. Connection banner → `authManager.connectionError`.

A raw `localizedDescription` for a failed Plex request can be a technical
`NSError` dump and can carry a token-bearing URL — both poor UX and a privacy
leak into on-screen copy (E0-G03 / E0-G08).

## Change (after)

Added a pure, `nonisolated`, unit-tested mapper
`HomeErrorPresentation.userFacingMessage(for:)`
(`Rivulet/Views/Media/HomeErrorPresentation.swift`):

- nil/empty → calm generic fallback;
- otherwise scrub via `SensitiveDataRedactor` (defense in depth), then
- if the scrubbed text still reads as technical (a URL, an `NSError`
  domain/code dump, a leftover redaction marker, or an `X-Plex` fragment) →
  generic fallback; clean, already-human-readable messages (offline, timed
  out, "check your network") pass through unchanged.

Wired at all three Home display points **consumer-side only** — no change to
`PlexDataStore` stored values and no change to `PlexAuthManager` (Epic 1
credential lifecycle, must-not-change). Error *detection* is unchanged; only the
displayed message is sanitized.

## Security / privacy

Closes a UI leak vector: a token-bearing or technical error string can no
longer reach on-screen Home copy. No tokens, credentials, or URLs in any Home
error message. Consistent with E0-G01/G03/G08. No new network surface.

## Accessibility (A11Y-001)

Error/empty/loading states keep E2-PR1's accessible surface: combined VoiceOver
element for descriptive text, deterministic initial focus on the retry control,
motion-free presentation. Copy is now plain-language. Device capture pending
(`DEBT-E0-007`).

## Scope guardrails honored

- No `ContentStateView`/`RenderState` redesign (structure already correct).
- No `PlexDataStore` or `PlexAuthManager` change (consumer-side sanitization).
- No Plex error-mapping rewrite, no provider-contract change, no generic
  app-wide error architecture — Home surfaces only.

## Validation

- `xcodebuild build` exit 0, 0 errors.
- `HomeErrorPresentationTests` (10) pass: nil/empty fallback, clean-message
  passthrough, token-URL/NSError/bare-token never leak, `looksTechnical`.
  `RenderStateResolverTests` and `SidebarNavigationPolicyTests` still pass.
- `git diff --check` clean.
