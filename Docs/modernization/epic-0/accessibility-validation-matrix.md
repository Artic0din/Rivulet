# Accessibility Validation Matrix

## Purpose

This matrix defines the minimum accessibility validation required for primary Rivulet flows. It is the baseline inherited by Epics 2, 3, 4, and 5.

## Validation Modes

| Mode | Description |
| --- | --- |
| Focus Path | Deterministic navigation using tvOS focus and remote input |
| VoiceOver | Spoken order, labels, traits, and operability with VoiceOver enabled |
| Reduced Motion | Usability when system motion reduction is enabled |
| Contrast / Readability | Legibility, clipping, and overlay readability |
| Exit Behavior | Reliable Menu/back/dismiss path from the flow |

## Flow Matrix

| Flow ID | Screen or Flow | Focus Path Required | VoiceOver Required | Reduced Motion Required | Contrast / Readability Required | Exit Behavior Required | Owning Epic | Evidence Required |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| A11Y-001 | App launch to home | Yes | Yes | Yes | Yes | Yes | Epic 2 | Video capture, VoiceOver notes, launch screenshots |
| A11Y-002 | Sidebar navigation | Yes | Yes | No | Yes | Yes | Epic 2 | Sidebar focus-path video and VoiceOver notes |
| A11Y-003 | Home hero actions | Yes | Yes | Yes | Yes | Yes | Epic 2 | Hero screenshots, action validation, focus notes |
| A11Y-004 | Continue Watching row | Yes | Yes | No | Yes | Yes | Epic 2 | Row navigation video and label audit |
| A11Y-005 | Poster to preview expansion | Yes | Yes | Yes | Yes | Yes | Epic 3 | Preview expansion video and VoiceOver notes |
| A11Y-006 | Preview paging left/right | Yes | Yes | Yes | Yes | Yes | Epic 3 | Paging capture and focus restoration notes |
| A11Y-007 | Preview exit to source row | Yes | No | No | No | Yes | Epic 3 | Exit video proving correct focus return |
| A11Y-008 | Detail page primary actions | Yes | Yes | No | Yes | Yes | Epic 3 | Detail page focus map and VoiceOver notes |
| A11Y-009 | Detail page seasons/episodes navigation | Yes | Yes | No | Yes | Yes | Epic 3 | Episodic navigation recording |
| A11Y-010 | Watchlist and discover actions | Yes | Yes | No | Yes | Yes | Epic 3 | Action sheet and state-change notes |
| A11Y-011 | Playback controls overlay | Yes | Yes | No | Yes | Yes | Epic 4 | Player controls capture with VoiceOver |
| A11Y-012 | Audio/subtitle track selection | Yes | Yes | No | Yes | Yes | Epic 4 | Track sheet video and label audit |
| A11Y-013 | Playback error and recovery UI | Yes | Yes | No | Yes | Yes | Epic 4 | Error-state capture and dismissal notes |
| A11Y-014 | Settings root and subpages | Yes | Yes | No | Yes | Yes | Epic 2 and Epic 5 | Settings navigation capture and descriptor review |
| A11Y-015 | Authentication and profile switching | Yes | Yes | No | Yes | Yes | Epic 1 | Auth/profile flow capture and PIN path notes |
| A11Y-016 | Top Shelf deep-link entry | Yes | No | No | No | Yes | Epic 2 | Top Shelf launch capture and landing-state notes |

## Success Criteria

### Focus Path

- No dead-end focus positions
- No unexpected focus jumps
- No loss of focus on modal entry or exit
- Correct restoration to origin after preview, sheet, or overlay dismissal

### VoiceOver

- Every actionable item has a meaningful label
- Order matches the visual and interaction hierarchy
- Actions are operable without hidden or unreachable focus targets

### Reduced Motion

- Critical information remains accessible without motion-dependent cues
- Preview and hero transitions remain understandable when motion is reduced

### Contrast / Readability

- Primary text remains readable over video and artwork
- Metadata overlays do not blend into artwork
- Truncated text remains understandable or is otherwise recoverable

### Exit Behavior

- Menu/back always exits or dismisses predictably
- Player and overlay exit behavior matches user expectation

## Evidence Template

```markdown
## Accessibility Validation Record

- Flow ID:
- Date:
- Build:
- Device:
- Reviewer:
- Focus path result:
- VoiceOver result:
- Reduced motion result:
- Contrast/readability result:
- Exit behavior result:
- Issues:
- Final decision:
```

## Review Requirements

1. Every primary flow changed by an epic must be revalidated.
2. Device validation is required for Home, Preview, Detail, Playback, and Top Shelf before Epic 5.
3. A failed primary-flow accessibility check is a blocker unless the affected scope is explicitly removed from the shipping plan.

## Acceptance Criteria

This matrix is acceptable when:

1. All primary flows are covered.
2. Every flow states the required validation modes.
3. Evidence requirements are explicit and reusable.
4. Reviewers can use the matrix to reject incomplete accessibility validation.

## Captured Validation Notes

| Flow ID | Date | PR | Level | Notes |
| --- | --- | --- | --- | --- |
| A11Y-002 | 2026-06-01 | E2-PR3 | Code/policy audit (device pending) | Sidebar/content focus ownership documented; Home row focus restoration made deterministic and stale-safe (no focus stranded on vanished items after refresh); reduced-motion and VoiceOver order unchanged. Pure-policy test coverage via `E2-PR3-TEST-001`. On-device VoiceOver/focus validation still required before Epic 5 (`DEBT-E0-007`). Evidence: `E2-PR3-AUDIT-001`, `E2-PR3-A11Y-001`. |
| A11Y-001 / A11Y-003 | 2026-06-01 | E2-PR4 | Code/policy audit (device pending) | Hero-first launch; deterministic initial focus on hero Play; hero button VoiceOver labels; Reduce Motion gates hero crossfade + paging dots. Device capture pending (`DEBT-E0-007`). Evidence: `E2-PR4-A11Y-001`, `E2-PR4-FOCUS-001`. |
| A11Y-004 | 2026-06-01 | E2-PR5 | Code/policy audit (device pending) | Continue Watching card exposed as one combined VoiceOver element (title, episode, time remaining, percent watched); CW pinned as the first/most-prominent row. Device capture pending (`DEBT-E0-007`). Evidence: `E2-PR5-A11Y-001`, `E2-PR5-POLICY-001`. |
| A11Y-002 | 2026-06-01 | E2-PR6 | Code/policy audit (device pending) | Top-level navigation determinism extracted into tested `SidebarNavigationPolicy`: changes blocked during nested/Settings-sub-page navigation, account row never strands selection, disabled/invalid tab falls back to Home. Native focus-guard swizzle + recovery watchdog + Menu/back unchanged. VoiceOver order/labels unchanged. Device VoiceOver/focus capture still required before Epic 5 (`DEBT-E0-007`). Evidence: `E2-PR6-A11Y-001`, `E2-PR6-POLICY-001`, `E2-PR6-TEST-001`. |
| A11Y-001 | 2026-06-01 | E2-PR7 | Code/policy audit (device pending) | Home error/empty/loading states keep the E2-PR1 accessible surface (combined VoiceOver element, deterministic retry focus, motion-free); error copy is now sanitized to plain language with no token/URL/technical dump (UAT-E2-07/08 leak case). Device capture pending (`DEBT-E0-007`). Evidence: `E2-PR7-COPY-001`, `E2-PR7-SEC-001`, `E2-PR7-A11Y-001`. |
| A11Y-005 / A11Y-006 / A11Y-007 | 2026-06-01 | E3-PR3 | Code/policy audit (device pending) | Preview structural transitions (entry morph, paging, expand, collapse) now honour Reduce Motion via tested `PreviewMotionPolicy` (instant, lossless state change). Exit decision (collapse-to-carousel vs dismiss) test-locked in `PreviewStateMachine`; focus restoration returns to the originating poster (unchanged). Device VoiceOver/focus capture pending (`DEBT-E0-007`). Evidence: `E3-PR3-MOTION-001`, `E3-PR3-DETERMINISM-001`, `E3-PR3-FOCUS-001`. |
