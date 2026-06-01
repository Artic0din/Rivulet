# Rivulet Content Design Language

Date: 2026-06-01
Owner: Epic 3 owner (E3-PR2)
Status: Canonical. Tracked source of truth for content-surface design values.

Rivulet's untracked `Docs/DESIGN_GUIDE.md` describes the philosophy
(Simplicity First, Elegant Restraint, Liquid Glass, Subtle Motion). This
document is the **governed, tracked** companion that pins the concrete values,
implemented as code in `Rivulet/Views/Components/ContentDesignTokens.swift`.

## Layering

| Layer | Owner | Holds |
| --- | --- | --- |
| Physical sizes | `ScaledDimensions` (`Services/UIScale.swift`) | Poster/card sizes, grid metrics, base type sizes, spacing, radii, `uiScale` |
| Semantic tokens | `ContentDesignTokens` (E3-PR2) | Focus opacities, focus/press scales, motion springs, shape depth, metadata type ramp |
| Components | `GlassRowStyle`, cards, detail, preview | Consume tokens; no inline design literals |

`ContentDesignTokens` sits **on top of** `ScaledDimensions`; the type ramp
aliases `ScaledDimensions` sizes so physical size has a single source of truth.

## Tokens

### Opacity (Glass surfaces, over white)
- Glass fill: focused `0.18`, resting `0.08`
- Glass border: focused `0.30`, resting `0.10`
- Glass focus shadow: `0.10`
- Standalone button resting fill: `0.15`
- Inline action resting fill: primary `0.20`, secondary `0.12`
- Inline action resting stroke: `0.20`

### Scale (focus/press emphasis — Elegant Restraint)
- Row focus `1.02`, action-button focus `1.08`, standalone-button focus `1.10`
- Pressed `0.95`, resting `1.0`

### Motion (subtle springs, no overshoot)
- Row focus: `spring(response: 0.30, dampingFraction: 0.70)`
- Control focus: `spring(response: 0.25, dampingFraction: 0.80)`
- Press: `spring(response: 0.15, dampingFraction: 0.90)`

### Shape / depth
- Corner radius `16`, shadow radius `8`, shadow Y `2`

### Metadata type ramp (large → small, aliases `ScaledDimensions`)
- hero `56` → section `30` → card title `24` → card subtitle `19`

## Rules

1. New content surfaces consume `ContentDesignTokens`, never inline design
   literals. Physical sizes still come from `ScaledDimensions`.
2. Token seeds equal the literals they replaced (E3-PR2 was behavior-identical);
   `ContentDesignTokensTests` pins the seeds — changing a token is a deliberate,
   reviewed design decision, not an accident.
3. Distinctness: this is Rivulet's own Glass identity. No Apple asset, name,
   layout, or trade-dress cloning.
4. Reduced Motion: motion tokens describe the default; surfaces honour
   `accessibilityReduceMotion` by suppressing or shortening motion (see E3-PR3/PR6).

## Content Presentation System (E3-PR6)

`ContentPresentationPolicy.swift` is the pure, tested decision layer for content
presentation. It holds no playback logic (inputs are resolved presentation
values), so it never touches the Epic 4 boundary.

- **Style** — `ContentPresentationStyle` (`landscape` / `poster` /
  `posterExpandsToLandscape`), default `poster`. `resolveStyle(preferred:
  hasLandscapeArtwork:)` degrades landscape styles to poster when landscape art
  is missing (no empty frames). Enum-based, never raw bools.
- **Title treatment** — `TitleTreatmentPolicy.resolve` order: Plex logo → TMDb
  logo → TVDb logo → text title. Never blocks render.
- **Artwork** — `ArtworkFallbackPolicy.resolve` order: landscape → backdrop crop
  → poster-derived → placeholder. Always yields something to render.
- **Runtime** — `RuntimeFormatter.format(minutes:)` → "2h 32m" / "47m"; nil when
  non-positive.
- **Content rating** — `ContentRatingPresentation.normalized` trims/validates;
  never invents a rating.
- **Technical badges** — `TechnicalBadgePolicy`: one badge per dimension in
  order resolution → video → audio (e.g. "4K • Dolby Vision • Atmos");
  `highestPriority(from:order:)` picks the highest-value candidate per dimension
  to avoid spam.
- **Metadata hierarchy** — `MetadataHierarchyPolicy.build` assembles the
  canonical hierarchy: title treatment → Rating · Year · Runtime → badges →
  description, nil-filtered and deterministic.

All of the above are covered by `ContentPresentationPolicyTests`. Card views
(E3-PR7) consume these; nothing renders presentation logic inline.

## Adoption status

- E3-PR2: `GlassRowStyle` (all button styles + glass background + row modifier)
  refactored to tokens — behavior-identical.
- Later slices (E3-PR3/PR4) adopt tokens as the preview and detail surfaces are
  touched; pre-existing inline literals elsewhere are migrated opportunistically
  when a surface is already being changed (no blanket rewrite).
