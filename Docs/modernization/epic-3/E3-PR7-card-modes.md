# E3-PR7 — Landscape Card + Poster→Landscape-on-Focus Modes

Date: 2026-06-01
Owner: Epic 3 owner
Workstream: WS-A/B (Content Presentation System)
Branch: `codex/epic-2-pr4-canonical-hero`

## Objective

Provide production-ready landscape and poster→landscape-on-focus card
presentations that consume the E3-PR6 policy layer, with deterministic focus,
reduced-motion support, no focus-time network, and graceful fallback.

## Change

`LandscapeContentCard` (`Rivulet/Views/Media/LandscapeContentCard.swift`):

- Renders the canonical hierarchy via the E3-PR6 policies: artwork
  (`CardArtwork` from `ArtworkFallbackPolicy`), lower-left title treatment
  (`TitleTreatment` logo or text), info line, and technical badges.
- `style`: `.landscape` (always landscape), `.poster` (poster only), and
  `.posterExpandsToLandscape` (poster at rest, landscape composition on focus).
- Focus emphasis uses `ContentDesignTokens` scale/motion; motion is gated by
  Reduce Motion via `PreviewMotionPolicy.animation` (instant when reduced).
- **No focus-time network fetch**: artwork/logo URLs are passed in already
  resolved; only `CachedAsyncImage` loading occurs, and the poster image for the
  at-rest state is loaded up front.
- Accessibility: one combined VoiceOver element via the pure, tested
  `ContentCardAccessibility.label(...)`; `.isButton` trait.
- Graceful fallback: logo → text title; artwork → placeholder; never blocks.

A `#Preview` exercises the component in Xcode (DEBUG only).

## Deferred with debt (acceptance §20.7 permits this)

The component is **additive** — it is not yet wired into the Home/Library/
Discover rows, because migrating the existing `MediaPosterCard`/row infrastructure
is a broad change that needs on-device focus/animation validation (no device or
live fixture available locally — `DEBT-E0-007`/`DEBT-E1-PR1-004`). Production
adoption + device validation is tracked as `DEBT-E3-PR7-001`. Because it is not
wired in, it cannot regress existing surfaces.

## Scope guardrails honored

- No playback / Epic 1 / project-setting / rename change.
- No existing card/row replaced; purely additive component.
- No focus-time network fetch; reduced-motion honoured.

## Validation

- `xcodebuild build` exit 0, 0 errors.
- `ContentCardAccessibilityTests` (4) + `ContentPresentationPolicyTests` (17)
  pass → ** TEST SUCCEEDED **.
- `git diff --check` clean.
