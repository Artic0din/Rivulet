# ADR-006: Accessibility Validation Standard

**Date**: 2026-05-31  
**Status**: accepted  
**Owner**: Ryan Foyle  
**Review cadence**: Review at the start of Epics 2, 3, and 4, and again during Epic 5 validation

## Context

Rivulet is a tvOS application. Focus behavior, VoiceOver operability, Menu/back handling, overlay transitions, and readability are core usability concerns rather than edge cases. The repo already contains strong focus-aware UI patterns, but there is no formal app-wide validation standard governing them.

Without a validation standard, accessibility quality is likely to vary screen-by-screen and reviewer-by-reviewer, especially across Home, Preview, Detail, and Playback.

## Decision

Rivulet will validate accessibility through a flow-based standard that covers:

- deterministic focus path
- VoiceOver order and labeling
- reduced-motion behavior where motion is material
- contrast and readability for major content surfaces
- exit behavior via Menu/back

Primary flows must be recorded in the accessibility validation matrix, and changed flows must be revalidated as part of the owning epic.

## Alternatives Considered

### Alternative 1: Rely on ad-hoc accessibility spot checks

- **Pros**: Low overhead
- **Cons**: Inconsistent; easy to miss regressions; poor release confidence
- **Why not**: Rejected because tvOS UX quality depends heavily on consistent focus and exit behavior

### Alternative 2: Limit accessibility review to Epic 5

- **Pros**: Fewer checks during active development
- **Cons**: Problems surface too late; remediation becomes expensive and destabilizing
- **Why not**: Rejected because the approved roadmap explicitly makes accessibility a day-one concern

### Alternative 3: Validate only with VoiceOver

- **Pros**: Clear single tool
- **Cons**: Misses critical focus, reduced-motion, and exit-path issues that matter on tvOS
- **Why not**: Rejected because accessibility on Apple TV is broader than VoiceOver alone

## Consequences

### Positive

- Accessibility evidence becomes reusable and comparable across epics
- Focus and exit behavior get treated as primary acceptance criteria
- Reviewer expectations become consistent

### Negative

- Design and implementation work will need more validation time
- Device testing burden increases for core flows

### Risks

- Teams may treat the matrix as checklist theater if they do not attach real evidence
- Reduced-motion or contrast issues may still be missed if validation stays simulator-only

Mitigation:

- Require evidence, not just checkboxes
- Require device validation for the major flows before ship
- Link all validation results in the evidence register
