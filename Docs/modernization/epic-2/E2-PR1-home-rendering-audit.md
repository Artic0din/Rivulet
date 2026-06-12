# E2-PR1 — Home Rendering Audit

Date: 2026-06-01

Owner: Epic 2 owner

Scope: current-state audit of the Home rendering flow, captured before/with the
E2-PR1 render-state + performance-harness foundation. Evidence for gate E0-G10.

## Entry points and shell

- App launch shell: `Rivulet/ContentView.swift` hosts `TVSidebarView()` with a
  splash overlay (`showSplash`, default `true` in Release). Splash dismisses when
  `PlexDataStore.isHomeContentReady` becomes `true` (500 ms debounce) or when
  there are no credentials, or after a 15 s safety timeout.
- Home screen: `Rivulet/Views/Media/PlexHomeView.swift` (≈1500 lines).
- Home data source: `PlexDataStore.shared` (`@Published var hubs: [PlexHub]`,
  `isLoadingHubs`, `hubsError: String?`, `hubsVersion`, `isHomeContentReady`).

## Render-state flow (pre-PR)

`PlexHomeView.body` expressed render state as an inline `if/else` ladder:

1. `!authManager.hasCredentials` → `notConnectedView`
2. `isLoadingHubs && hubs.isEmpty` → `loadingView`
3. `hubsError != nil && hubs.isEmpty` → `errorView(error)`
4. `hubs.isEmpty` → `emptyView`
5. else → `contentView`

Observed precedence: **content > loading > error > empty** (content present always
renders, even mid-refresh). This is the precedence E2-PR1 formalises in
`RenderStateResolver`.

State presentations (pre-PR), now centralised unchanged in `ContentStateView`:

- loading: `ProgressView().scaleEffect(1.5)` + "Loading".
- error: `exclamationmark.triangle` + "Unable to Load" + live error + "Try Again"
  (→ `refreshHubs`).
- empty: `film.stack` + "No Content" + "Your Plex library appears to be empty." +
  "Refresh" (→ `refreshHubs`).
- not-connected: `server.rack` + "Not Connected" + settings hint. **Left in
  `PlexHomeView`**; auth is an Epic 1 boundary and intentionally outside the
  content render-state model.

## Data composition

- `HomeComposer.compose(provider:)` → `[MediaHub]`: prefers Plex-native
  `provider.hubs()`; falls back to `synthesizeFromPrimitives` (continueWatching +
  recentlyAdded) for non-Plex providers. Consumed via the Epic 1 `MediaProvider`
  boundary; not modified by this PR.
- `PlexHomeView` reads `dataStore.hubs` directly and memoises a processed copy in
  `cachedProcessedHubs` (recomputed on `hubsVersion` / `libraryHubsVersion` /
  Home library-selection changes).
- `MediaProvider` home rails: `continueWatching(limit:)`, `recentlyAdded(limit:)`,
  `hubs()`. Watchlist membership is read-only via `PlexWatchlistService`
  (`isOnWatchlist`). No provider writes (respects `DEBT-E1-PR10-001`).

## Continue Watching / Recently Added / hub rendering

- Rendered inside `contentView` from `cachedProcessedHubs` (per-hub rows). For
  Plex, hubs are server-curated; the synth path yields "Continue Watching" and
  "Recently Added" shelves when native hubs are empty.
- Personalised recommendations are a separate optional section
  (`recommendationsSection`, flag `enablePersonalizedRecommendations`, default
  off) with its own inline loading/error/empty handling — **left unchanged**
  (out of E2-PR1 scope; a future candidate for the shared surface).

## Hero behaviour and `showHomeHero`

- Hero is gated behind `@AppStorage("showHomeHero")`, default **`false`** — Home
  is currently row-first (matches parity scorecard "Home still row-first").
- `selectHeroItems()` runs on appear and on hub changes: uses cached hero items,
  then hub-backed candidates (`computeHubBackedHero`), then async upgrades via
  `upgradeHeroFromTMDB()` (TMDB popular ∩ library GUID index).
- E2-PR1 does **not** enable or restyle the hero. It only instruments hero
  preparation timing (PERF-003) so the budget is measurable when a later PR
  ships the hero.

## Focus initialisation and restoration

- `@FocusState private var focusedItemId: String?` ("context:itemId" format).
- Focus restoration within rows uses the existing `FocusMemory` /
  `remembersFocus` pattern (per `Services/Focus/FocusMemory.swift`); preview
  re-entry uses `previewRestoreTarget` / `capturedSourceFrames`.
- E2-PR1 adds deterministic initial focus only to the new shared state surface's
  retry control (error/empty). It does **not** change Home content focus,
  sidebar focus, or restoration — that is later Epic 2 (WS-E) work.

## Observability / deep-link (context)

- `PlexHomeView` already logs via `Logger(subsystem: "com.rivulet.app",
  category: "PlexHome")` — matches the ADR-005 taxonomy.
- Deep links: `rivulet://detail?ratingKey=` / `rivulet://play?ratingKey=` via
  `NSUserActivity` in `RivuletApp.swift` (`NET-021`); not touched by this PR.

## Gaps carried forward (not addressed in E2-PR1, by design)

- Hero is off by default and not yet canonical (E2-PR4).
- No shared empty/error styling for `recommendationsSection` or library/discover
  views yet — only Home's primary state ladder is migrated here.
- No live performance baseline numbers yet (`DEBT-E0-008`); E2-PR1 provides the
  capture harness, first numbers are recorded in the performance evidence record.
- Cold vs warm launch are not distinguished by the in-app launch mark; absolute
  process-launch timing relies on OS signposts / Instruments per the Epic 0 perf
  doc. Noted as a follow-up refinement.

## Architecture direction (binding for later Epic 2 work)

`RenderState` and `ContentStateView` are now the preferred Epic 2 Home-state
architecture. Future Home Hero, Continue Watching, Discovery, Sidebar, and
Home-row work should consume these abstractions rather than introducing parallel
loading/error/empty implementations.
