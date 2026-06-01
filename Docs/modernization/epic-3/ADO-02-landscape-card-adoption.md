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
- **LANDSCAPE card: LIVE** in Recently Added.
- **ContentPresentationPolicy: LIVE** (via the mapper + `showsLandscapeComposition`).
- **poster→landscape-on-focus: LIVE** (correction pass). Recently Added now uses
  `.posterExpandsToLandscape`: poster-shaped at rest, landscape composition on
  focus. See §Correction below.
- Technical badges: not mapped (no quality data wired) → no badge spam; future ADO.

## Correction pass — poster→landscape-on-focus made live

The initial ADO-02 used `.landscape` (always) and deferred poster→landscape-on-
focus. That left the slice partial. The correction makes it live in the same
Recently Added row, safely:

- The card keeps a **constant footprint** (`continueWatchingWidth × Height`,
  392×280) in *every* state. The row height is therefore constant and cells
  never reflow, clip, or overlap as focus moves.
- **At rest**: the poster image is shown `.fit` (poster-shaped, no crop) centered
  on a dark gutter fill — a poster-shaped resting state.
- **On focus**: cross-fade to the landscape artwork (`.fill`) + lower-left
  logo/title/metadata overlay.
- The resting/focused decision is the tested
  `ContentPresentationPolicy.showsLandscapeComposition(style:isFocused:)`.
- Both images load at **render** (stacked + opacity cross-fade), so focus
  movement triggers **no** network fetch. Cross-fade is gated by Reduce Motion
  (instant swap when reduced — no info lost).
- **Accessibility identity is stable**: the same combined VoiceOver label is used
  in both states (does not depend on focus/landscape), so VoiceOver never sees
  duplicate or shifting elements.

Row selection, carousel preview, focus restoration, left/right navigation, and
return focus are all unchanged (the host Button still owns them).

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
3. Those cards now render **poster-shaped at rest**, and **expand/cross-fade to a
   landscape card** (lower-left logo/title, Rating · Year · Runtime) **when
   focused**. Other rows (Continue Watching, etc.) are unchanged.
4. Move focus across the row: the resting cards are posters; the focused card
   shows the landscape composition. Row height stays constant (no thrash); no
   clipping/overlap; horizontal scroll and return-focus preserved.
5. Click a focused card → same detail/preview as before.
6. VoiceOver: a card announces "Title, Rating, Year, Runtime" in both states
   (stable identity).
7. Reduce Motion on: the swap is instant (no cross-fade), still poster→landscape.

## Debt
- `DEBT-E3-PR7-001` **substantially reduced**: landscape card,
  `ContentPresentationPolicy`, **and** poster→landscape-on-focus are all now LIVE
  in the Recently Added row. **Still open**: broader row migration (only Recently
  Added uses these cards) and technical-badge mapping.

## Recommendation for ADO-03
Schedule labels (`ScheduleLabelPolicy`) onto hero/detail, OR adopt
`.posterExpandsToLandscape` on a second row — both small/medium. Validate this
ADO-02 row visually on a device first.
