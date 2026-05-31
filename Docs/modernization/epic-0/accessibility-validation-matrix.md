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
