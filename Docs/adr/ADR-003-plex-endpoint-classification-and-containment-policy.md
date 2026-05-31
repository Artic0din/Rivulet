# ADR-003: Plex Endpoint Classification and Containment Policy

**Date**: 2026-05-31  
**Status**: accepted  
**Owner**: Ryan Foyle  
**Review cadence**: Review before Epic 1 closes and whenever a new endpoint family is introduced

## Context

Rivulet talks to several different Plex endpoint families:

- official `plex.tv` account and resource APIs
- PMS browse and playback APIs on the selected server
- legacy XML endpoints still used as fallback behavior
- unstable provider/discover endpoints used for watchlist and metadata matching

The repo already reflects this mixture. The problem is not that the endpoints exist; the problem is that they are not yet governed by one classification model. Without classification, discover/watchlist behavior, legacy fallbacks, and PMS flows can become intertwined in ways that are hard to secure or retire.

## Decision

Rivulet will classify every Plex-facing endpoint into one of the following classes:

1. Official account/resource API
2. Official PMS API
3. Official third-party device behavior
4. Unstable provider/discover surface
5. Legacy or fallback surface

Each class must have an owning adapter and explicit containment rules. Unstable provider/discover and legacy surfaces may remain in use, but they must not be allowed to spread across the codebase as informal dependencies.

## Alternatives Considered

### Alternative 1: Treat all Plex endpoints as one unified API surface

- **Pros**: Simplifies documentation
- **Cons**: Hides real stability and ownership differences; makes review and retirement harder
- **Why not**: Rejected because the repo clearly spans multiple behavioral contracts

### Alternative 2: Immediately remove all legacy and unstable surfaces

- **Pros**: Cleaner architecture and lower long-term risk
- **Cons**: Unrealistic in the short term; could break watchlist/discover and home-user functionality
- **Why not**: Rejected because the product still depends on some of these surfaces today

### Alternative 3: Document endpoint differences only in code comments

- **Pros**: Low overhead
- **Cons**: Easy to drift; not reviewable at epic level; not suitable for governance
- **Why not**: Rejected because Epic 1 needs a program-level containment model

## Consequences

### Positive

- Epic 1 gets a clear modernization target for Plex integration
- Reviewers can distinguish acceptable use from risky spread of unstable or legacy behavior
- Future retirement of legacy XML or unstable discover paths becomes tractable
- Security and privacy reviews can focus on the highest-risk surfaces first

### Negative

- The first classification pass adds documentation and adapter work
- Some code may look more verbose while containment boundaries are introduced

### Risks

- Discover/provider endpoints may change faster than the classification documents are updated
- Teams may misuse “contained” as justification for leaving poor behavior indefinitely

Mitigation:

- Require every unstable or legacy surface to have an owner
- Link all such surfaces in the network inventory
- Re-review the classification at each Epic 1 milestone
