# E3-PR5 — Watchlist / Discover / Universal / More-Ways Presentation

Date: 2026-06-01
Owner: Epic 3 owner
Workstream: WS-D
Branch: `codex/epic-2-pr4-canonical-hero`

## Objective

Improve presentation and failure/empty states for the Discover and watchlist
surfaces without changing the Epic 1 provider/endpoint boundary or the watchlist
mutation contract.

## Audit findings (before)

- Watchlist write feedback already uses calm, controlled copy ("Couldn't update
  Watchlist", "Sign in to use Watchlist") via `PlexWatchlistService.surface(_:)`
  + the `watchlistToast` — no raw error, no leak. **No change needed.**
- `DiscoverViewModel` exposed only a `loading` flag and no error/empty signal.
  `TMDBDiscoverService.fetchSection` degrades failures to empty results, so a
  Discover page that resolves no content rendered a **blank screen** — no calm
  loading or empty surface.

## Change (after)

- Added a pure, tested `DiscoverPresentation.phase(isLoading:hasContent:)`
  (content > loading > empty; no error channel since fetches degrade to empty),
  and exposed `DiscoverViewModel.hasContent` / `presentationPhase`.
- `DiscoverView` now overlays the shared `ContentStateView` with a calm
  loading label ("Finding Something to Watch") and a `discoverEmpty`
  presentation when no hero/section/For-You content is present. The overlay is
  non-interactive and never shown once any content resolves, so it cannot hide
  real content.

No provider/endpoint/boundary change; no watchlist mutation added.

## DEBT-E1-PR10-001 reassessment (provider watchlist write contract)

**Carried, not resolved.** Resolving it requires `MediaProvider.addToWatchlist`
/`removeFromWatchlist` to accept account-token + display metadata — i.e. a change
to the Epic 1 `MediaProvider` protocol boundary, which is explicitly forbidden
this epic ("Do not modify Epic 1 boundaries / provider abstraction") and is a
defined stop condition. It is therefore not legitimately resolvable within Epic 3
constraints. Epic 3 adds **no** `addToWatchlist`/`removeFromWatchlist` calls. The
debt remains owned jointly (Epic 3 design + Epic 1 boundary support) and is
carried to a future boundary-authorised change.

## Accessibility (A11Y-010)

Discover/watchlist actions unchanged; the new empty/loading surface reuses
`ContentStateView`'s accessible, motion-free presentation (combined VoiceOver
element). Device capture pending (`DEBT-E0-007`).

## Validation

- `xcodebuild build` exit 0, 0 errors.
- `DiscoverPresentationTests` (4) + `RenderStateResolverTests` (12) pass →
  ** TEST SUCCEEDED **.
- `git diff --check` clean.
