# Epic 0 Gate Matrix

## Purpose

This matrix defines the inherited gates for every modernization epic. A gate is enforceable only if it has:

- an owner
- explicit review criteria
- required evidence
- a failure action

## Gate Status Values

| Status | Meaning |
| --- | --- |
| Operational | Gate rules and evidence model are defined and can be enforced now |
| Partially Operational | Gate exists but one or more required evidence paths are still being established |
| Not Operational | Gate is not yet enforceable; epic work depending on it should not be treated as complete |

## Cross-Cutting Gates

| Gate ID | Area | Status | Applies To | Rule | Required Evidence | Reviewer | Failure Action |
| --- | --- | --- | --- | --- | --- | --- | --- |
| E0-G01 | Security - Token Handling | Operational | Epics 1, 2, 3, 4, 5 | No token may be logged, surfaced in crash reports, or embedded in extension-distributed URLs unless explicitly covered by ADR-002 and documented as unavoidable | Code diff review, log sample, Sentry field review, affected test cases | Security reviewer + Project Owner | Merge blocked |
| E0-G02 | Security - Network Inventory | Operational | Epics 1, 2, 4, 5 | Every new host, endpoint family, or trust exception must be added to the network surface inventory before merge | Updated `security-network-surface-inventory.csv` entry | Security reviewer | Merge blocked |
| E0-G03 | Privacy - Disclosure Completeness | Operational | Epics 1, 2, 3, 4, 5 | Any new collected, stored, or transmitted user or device data must be added to the privacy disclosure matrix and manifest review | Updated disclosure matrix, manifest impact note | Privacy reviewer | Merge blocked |
| E0-G04 | Accessibility - Focus and VoiceOver | Operational | Epics 2, 3, 4, 5 | Any changed flow must document focus path, VoiceOver order, exit behavior, and reduced-motion impact | Accessibility validation record, screenshots or video | Accessibility reviewer | Merge blocked for primary flows; debt only for non-primary flows |
| E0-G05 | Testing - Command Proof | Operational | Epics 1, 2, 3, 4, 5 | Any claim that work passes requires fresh command output for the relevant test/build command | Test execution record with exit status | Epic reviewer | Merge blocked |
| E0-G06 | Testing - Regression Coverage | Partially Operational | Epics 1, 2, 3, 4, 5 | User-visible regressions must be covered by unit, integration, UI, or manual regression evidence appropriate to the change | Updated regression matrix entry, test results | Epic reviewer + domain reviewer | Merge blocked if regression risk is high |
| E0-G07 | Performance - Budget Adherence | Operational | Epics 2, 3, 4, 5 | Changes to launch, home, preview, or playback must not exceed published budgets without explicit debt acceptance | Performance run record, before/after metric comparison | Performance reviewer | Merge blocked for unexplained breaches |
| E0-G08 | Observability - Logging Policy | Operational | Epics 1, 2, 3, 4, 5 | New logs, events, breadcrumbs, or crash fields must use approved taxonomy and must not emit forbidden fields | Observability review record | Observability reviewer | Merge blocked |
| E0-G09 | ADR Governance | Operational | Epics 0, 1, 2, 3, 4 | Architectural changes touching auth, endpoints, trust, playback policy, observability, or accessibility standard require ADR review | ADR update or ADR exemption note | Project Owner | Merge blocked |
| E0-G10 | Documentation and Evidence Linking | Operational | Epics 1, 2, 3, 4, 5 | Every completed work package must link its evidence in the evidence register | Evidence register update | Epic reviewer | Cannot close epic work package |

## Epic-Specific Gate Application

### Epic 1 - Plex Platform Modernisation

| Gate | Why it applies | Additional proof required |
| --- | --- | --- |
| E0-G01 | Epic 1 owns token lifecycle and transport | Redaction tests, auth flow review, watchlist/discover containment notes |
| E0-G02 | Epic 1 introduces or changes the highest-risk network surfaces | Endpoint classification update for every changed path |
| E0-G03 | Epic 1 changes the handling of account/server/user credentials | Disclosure matrix updates for credentials, identifiers, and crash fields |
| E0-G05 | Auth and endpoint changes are high-risk regression surfaces | Command output for unit tests and targeted auth/network tests |
| E0-G08 | Epic 1 is responsible for bringing logs and Sentry fields under policy | Before/after log examples and scrubber verification |

### Epic 2 - Apple TV Home Experience

| Gate | Why it applies | Additional proof required |
| --- | --- | --- |
| E0-G04 | Home, hero, navigation, and focus are accessibility-critical | Focus-path evidence for sidebar, hero, and row transitions |
| E0-G07 | Launch and home are the first major perceived-performance surfaces | Launch and home render metric captures |
| E0-G08 | Home errors, loading states, and Top Shelf diagnostics must remain clean | Structured log review for home and Top Shelf surfaces |

### Epic 3 - Apple TV Content Experience

| Gate | Why it applies | Additional proof required |
| --- | --- | --- |
| E0-G04 | Preview and detail transitions are focus- and motion-sensitive | Poster -> preview -> detail accessibility evidence |
| E0-G07 | Preview expansion and detail loading must stay within budget | Preview latency and detail-load metric captures |
| E0-G08 | Discover, watchlist, and universal details often involve unstable metadata surfaces | Observability review of failures and fallbacks |

### Epic 4 - Playback Excellence

| Gate | Why it applies | Additional proof required |
| --- | --- | --- |
| E0-G01 | Playback paths currently leak stream URLs into Sentry and logs | Redaction validation for stream URLs and headers |
| E0-G04 | Player controls, track sheets, and recovery UI must remain operable | Playback control focus and VoiceOver evidence |
| E0-G07 | Playback startup, seek response, and memory growth are core product metrics | Media-corpus-backed performance captures |
| E0-G08 | Playback telemetry is explicitly owned by Epic 4 | Event and crash field review with approved tags/extras |

### Epic 5 - Release Readiness and Production Validation

| Gate | Why it applies | Additional proof required |
| --- | --- | --- |
| E0-G01 through E0-G10 | Epic 5 is the formal audit and release gate | Full evidence register, parity scorecard review, debt register review, explicit ship/no-ship recommendation |

## Review Rules

1. A gate review must cite the exact artifact and evidence it used.
2. A reviewer may not waive a blocker verbally; waivers must be written in the relevant artifact or linked debt register entry.
3. A partially operational gate may support active development, but it may not be used as justification to close an epic.
4. If multiple gates fail, the highest-severity failure controls the decision.

## Escalation Rules

| Failure Type | Escalation Path | Allowed Outcome |
| --- | --- | --- |
| Token leak | Security reviewer -> Project Owner | Fix before merge or explicit rollback of affected change |
| Privacy disclosure gap | Privacy reviewer -> Project Owner | Fix before merge or documented no-ship blocker |
| Accessibility blocker on a primary flow | Accessibility reviewer -> Project Owner | Fix before merge or scope reduction |
| Performance budget breach without explanation | Performance reviewer -> Epic owner -> Project Owner | Fix, justify with evidence, or accept debt with expiry |
| Missing evidence for a completion claim | Any reviewer -> Epic owner | Claim rejected until evidence is attached |

## Gate Acceptance Checklist

The following checklist must be true before any epic work package is accepted:

- [ ] Applicable Epic 0 gates identified
- [ ] Evidence linked in `evidence-register.md`
- [ ] Reviewer names recorded
- [ ] Any accepted debt recorded with owner and expiry
- [ ] No blocker gate remains open
