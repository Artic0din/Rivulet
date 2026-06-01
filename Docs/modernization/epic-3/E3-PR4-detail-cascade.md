# E3-PR4 — Detail Page Hierarchy and Metadata Cascade

Date: 2026-06-01
Owner: Epic 3 owner
Workstream: WS-C (Detail)
Branch: `codex/epic-2-pr4-canonical-hero`

## Objective

Make the detail-page metadata hierarchy coherent and deterministic without a
structural rewrite of the 3.7k-line `MediaDetailView` and without any playback
route change.

## Audit findings (before)

- The hero metadata cascade was built with inline conditionals: a
  `heroMetadataParts` computed property (type label + up to 2 genres) and a
  separate inline `year / "·" / duration` block with `year != nil && duration
  != nil` separator branching. Ordering was implicit and untested.
- `MediaDetailView` has granular `isLoadingSeasons/Episodes/Extras` spinners but
  no single load/error surface; a full `ContentStateView` adoption across a
  3.7k-line view is high-risk without a live fixture and is deferred (noted as a
  follow-up; the granular spinners already cover the sub-sections).

## Change (after)

Extracted the ordering into a pure, tested `DetailMetadataCascade`:

- `primaryParts(kind:genres:maxGenres:)` → media-type label (TV Show / Movie /
  none) followed by up to N genres. Replaces `heroMetadataParts`.
- `chronologyParts(year:duration:)` → ordered, nil-filtered `[year, duration]`,
  so the "·" separator logic is deterministic (no nil-branching). The quality
  row now renders this via the same `ForEach`/separator pattern as the primary
  line.

Both are behavior-identical to the prior inline logic (same segments, same
order). `MediaDetailView` delegates to the policy.

## Scope guardrails honored

- No playback route / data-cascade timing change; only textual-segment ordering
  moved behind a tested policy.
- No structural detail rewrite; no provider/boundary change.
- Quality badges, the rating star, and the bordered content-rating chip remain
  view concerns (the policy owns text-segment ordering only).

## Accessibility (A11Y-008/009)

VoiceOver reads the metadata line in a now-deterministic order (type → genres →
chronology); detail primary-actions and seasons/episodes structure are unchanged.
Device capture pending (`DEBT-E0-007`).

## Validation

- `xcodebuild build` exit 0, 0 errors.
- `DetailMetadataCascadeTests` (11) pass → ** TEST SUCCEEDED **: type mapping,
  genre cap, chronology order/nil-filtering.
- `git diff --check` clean.
