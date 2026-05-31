# ADR-001: Foundation Gate Model

**Date**: 2026-05-31  
**Status**: accepted  
**Owner**: Ryan Foyle  
**Review cadence**: Review at the start of each delivery epic and again during Epic 5 release validation

## Context

The approved Rivulet modernization roadmap is structured around product epics plus a cross-cutting Platform Foundation stream. The repo already shows why that structure is necessary: app-wide ATS bypass, token-bearing URLs in logs and Top Shelf, missing privacy manifest, inconsistent observability, and no formalized accessibility or performance gates.

Without a gate model, later epics could deliver visible product changes while silently increasing security, privacy, or verification debt. That would recreate the exact waterfall failure the approved roadmap is intended to avoid.

## Decision

Rivulet will use an inherited gate model for the modernization program.

Epic 0 defines the cross-cutting gates for security, privacy, accessibility, testing, performance, observability, and ADR governance. Epics 1 through 5 must satisfy the applicable Epic 0 gates before work is considered complete. Epic 0 is operational when those gates can be enforced consistently through documentation, evidence, and review.

## Alternatives Considered

### Alternative 1: Treat quality as a later phase

- **Pros**: Simpler early planning; less documentation up front
- **Cons**: Encourages feature work to outrun safety and verification; repeats the original waterfall weakness; makes late-stage remediation expensive
- **Why not**: Rejected because the approved roadmap explicitly forbids collapsing Epic 0 into a later quality phase

### Alternative 2: Keep only informal reviewer expectations

- **Pros**: Lower process overhead; flexible for rapid iteration
- **Cons**: Review quality varies by reviewer; no reusable evidence model; easy to ship undocumented exceptions
- **Why not**: Rejected because the repo already has high-risk cross-cutting debt that cannot be managed informally

### Alternative 3: Create separate gate models per epic

- **Pros**: Fine-tuned to local epic needs
- **Cons**: Fragmented standards; inconsistent evidence; duplicated work
- **Why not**: Rejected because the platform concerns cut across all epics and need one authoritative rule set

## Consequences

### Positive

- Every epic now inherits the same safety and verification contract
- Security, privacy, accessibility, performance, and observability can block unsafe work early
- Epic 5 becomes a real production-validation gate instead of the first time quality is checked
- Review becomes more objective because gate success is tied to evidence

### Negative

- Delivery work now has more documentation and evidence overhead
- Some feature work will slow down until the supporting foundation artifacts exist
- Reviewers must participate more actively in non-code validation

### Risks

- Teams may treat the documents as bureaucracy and stop using them operationally
- Gates may become stale if they are not revisited when architecture changes
- Overly rigid gate use could block low-risk iteration if reviewers do not distinguish blocker vs debt correctly

Mitigation:

- Keep the gate set focused on high-value risks
- Require evidence links rather than long prose
- Review the gate model at each epic boundary and at release validation
