# E3-PR11 — Cast/Crew Images and Accessibility

Date: 2026-06-01
Owner: Epic 3 owner
Workstream: Content Presentation System (Product Direction #2)
Branch: `codex/epic-2-pr4-canonical-hero`

## Audit findings

`PersonCard` already loads real cast/crew images through the safe
`CachedAsyncImage` pipeline, building the URL from existing Plex/mapper data and
appending the server token only for relative Plex thumb paths (no token added to
already-qualified URLs). So real cast/crew images are already supported. The
gaps were: a generic person-icon failure placeholder (not initials) and no
combined VoiceOver label.

## Change

- Pure, tested `CastImagePresentation`: `accessibilityLabel(name:role:)`
  ("Name, Role"; role omitted when empty) and `initials(from:)` (≤2 uppercase
  initials; "?" when empty).
- Wired into `PersonCard`: one combined VoiceOver element exposing name + role,
  and an initials avatar as the image-failure fallback instead of a generic
  icon — so a person cell never shows a broken/empty avatar and always exposes
  the name.

This is a leaf-component, additive change — no provider/boundary/playback change,
no new external metadata provider. Plex remains the image source; TMDb/TVDb
person images stay an optional future enhancement (not added).

## Accessibility (A11Y-008 cast region)

Each cast/crew cell is one VoiceOver element labelled "Name, Role"; failure
fallback shows readable initials. Device capture pending (`DEBT-E0-007`).

## Validation

- `xcodebuild build` exit 0, 0 errors.
- `CastImagePresentationTests` (6) pass → ** TEST SUCCEEDED **.
- `git diff --check` clean.
