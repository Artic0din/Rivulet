# ADO-02 — LandscapeContentCard Live Adoption (Recently Added row)

Date: 2026-06-01
Owner: Epic 3 owner
Branch: `codex/epic-2-pr4-canonical-hero`
Status: Complete (bounded — one row).

## Chosen surface
**Home "Recently Added" rows** (preferred surface #1). Movies/shows with Plex
`art` (landscape/backdrop) available; landscape cards suit this row.

## Audit (before)
- Row component: `InfiniteContentRow` (`PlexHomeView`). The row wraps each item in
  a focusable `Button` that owns selection/preview (`onPreviewRequested` +
  `previewSourceAnchor`)/focus (`@FocusState focusedItemId`)/context menu/paging.
  The card (`MediaPosterCard`) is only the Button's **visual label** — a plain
  View, not a button.
- Item model: `PlexMetadata`. Artwork via `art` (backdrop) + `thumb` (poster) +
  `clearLogoPath`; token-safe URL pattern (append `X-Plex-Token` only to relative
  paths).
- Landscape artwork: available (`art`).

## Change (after)
1. `LandscapeContentCard` refactored to a **presentation-only visual** (no
   internal `Button`/`@FocusState`); it takes `isFocused` from the host row,
   mirroring `ContinueWatchingCard`. So it slots in as a Button label with **all
   row wiring preserved**.
2. New tested `PlexContentCardMapper.model(from:serverURL:authToken:)` maps a
   `PlexMetadata` to a `ContentCardModel` using the Content Presentation System
   policies (`TitleTreatmentPolicy`, `ArtworkFallbackPolicy`,
   `MetadataHierarchyPolicy`, `RuntimeFormatter`, `ContentRatingPresentation`) —
   making **`ContentPresentationPolicy` LIVE**. Token-safe URL builder; no
   provider calls; no new network.
3. `InfiniteContentRow` gains `cardStyle: ContentPresentationStyle = .poster`
   (default preserves `MediaPosterCard`). When non-poster, it renders
   `LandscapeContentCard(model: mapper(item), style: resolveStyle(...),
   isFocused: focusedItemId == focusId(item))`.
4. `PlexHomeView` passes `cardStyle: isRecentlyAddedHub(hub) ? .landscape :
   .poster` — **only Recently Added rows** change; every other row keeps posters.

## What is / isn't live
- **LANDSCAPE card: LIVE** in Recently Added (always-landscape mode).
- **ContentPresentationPolicy: LIVE** (via the mapper).
- **poster→landscape-on-focus: NOT live** — I adopted the always-`.landscape`
  mode (fixed size, lowest layout risk). The `.posterExpandsToLandscape` mode
  exists and `resolveStyle` supports it, but is not yet wired to a row. Recorded
  separately under `DEBT-E3-PR7-001`.
- Technical badges: not mapped (no quality data wired) → no badge spam; future ADO.

## Behaviour preserved
Selection, preview (carousel) via the unchanged Button + `previewSourceAnchor`,
focus + focus-restoration (`FocusRestorationPolicy`, unchanged), context menu,
paging — all untouched. No provider/watch-state/token/playback change. No new
network or image preload on focus (artwork URLs resolved up front from existing
metadata; `CachedAsyncImage` loads as before).

## Accessibility
The landscape card exposes one combined VoiceOver element
(`ContentCardAccessibility.label`); artwork falls back landscape → poster →
placeholder; logo → text title; Reduce Motion gates the focus emphasis. Device
capture pending (`DEBT-E0-007`).

## Tests
`PlexContentCardMapperTests` (8: token-safe URL building incl. no-leak +
no-duplicate-token, landscape/poster fallback, info-line, hasLandscapeArtwork);
`ContentPresentationPolicyTests` (15), `ContentCardAccessibilityTests` (4),
`FocusRestorationPolicyTests` (10), `FocusMemoryTests` (6),
`PlexProviderBoundaryTests` — all pass → ** TEST SUCCEEDED **.

## Validation
`git diff --check` clean; `xcodebuild build` exit 0.

## Simulator validation instructions
1. Run Rivulet on the Apple TV sim, sign into Plex.
2. Home → scroll to a **"Recently Added <Library>"** row.
3. Those cards now render as **landscape** cards (lower-left logo/title overlay,
   Rating · Year · Runtime) instead of portrait posters. Other rows
   (Continue Watching, etc.) are unchanged.
4. Focus a card: subtle scale; click → same detail/preview as before; left/right
   moves between cards; returning preserves focus.
5. VoiceOver: a card announces "Title, Rating, Year, Runtime".

## Debt
- `DEBT-E3-PR7-001` **reduced**: landscape card + `ContentPresentationPolicy` now
  live in one row. **Still open**: broader row migration (only Recently Added
  converted) and the `.posterExpandsToLandscape` mode (built, not wired).

## Recommendation for ADO-03
Schedule labels (`ScheduleLabelPolicy`) onto hero/detail, OR adopt
`.posterExpandsToLandscape` on a second row — both small/medium. Validate this
ADO-02 row visually on a device first.
