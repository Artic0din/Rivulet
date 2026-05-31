# ADR-007: Performance Measurement and Budget Model

**Date**: 2026-05-31  
**Status**: accepted  
**Owner**: Ryan Foyle  
**Review cadence**: Review before Epic 2 closes, before Epic 4 closes, and during Epic 5 release validation

## Context

Rivulet’s product goals depend on perceived speed and stability:

- launch must feel immediate
- home and preview transitions must feel premium
- playback startup and seek behavior must feel trustworthy

The repo already contains performance-sensitive architecture, especially in playback. It also carries unresolved stability and concurrency debt that can distort performance. There is currently no single published budget model tying launch, preview, and playback to measurable pass/fail thresholds.

## Decision

Rivulet will use a budget-based performance model with explicit metrics for:

- launch
- home hero readiness
- preview expansion
- playback startup
- seek response
- focus response
- image cache hits
- extended-session memory growth

Performance claims must cite measured evidence using the published metric IDs and media corpus where relevant.

## Alternatives Considered

### Alternative 1: Use only qualitative “feels fast enough” review

- **Pros**: Minimal process overhead
- **Cons**: Reviewer-dependent; hard to detect regressions; not defensible at release time
- **Why not**: Rejected because subjective feel alone is not enough for playback and launch quality

### Alternative 2: Define budgets only for playback

- **Pros**: Focuses on highest technical risk
- **Cons**: Ignores home, preview, and launch, which strongly shape perceived quality
- **Why not**: Rejected because Apple TV-like parity depends on more than player startup

### Alternative 3: Wait for full instrumentation before setting budgets

- **Pros**: Budgets could be tied to richer data
- **Cons**: Leaves active development ungated; encourages regressions before the tooling exists
- **Why not**: Rejected because even provisional budgets are better than no budgets

## Consequences

### Positive

- Feature work can be reviewed against explicit thresholds
- Launch, preview, and playback quality become first-class acceptance criteria
- Media-corpus-backed playback validation becomes measurable

### Negative

- Instrumentation and capture work must happen earlier
- Some work will be slowed by measurement requirements

### Risks

- Budgets may need tuning as real device data accumulates
- Instrumentation may perturb measurements if implemented carelessly
- Teams may optimize for individual metrics while missing broader stability issues

Mitigation:

- Revisit budgets as the first device baselines are captured
- Record both median and p95 where practical
- Pair performance evidence with stability observations and media-corpus coverage
