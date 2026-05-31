# Epic 0 Debt Register

## Purpose

This register tracks accepted, open, and release-blocking debt relevant to Epic 0 and to the inherited gates for later epics.

Debt is not a hidden backlog. Every entry must have:

- a stable ID
- an owner
- a severity
- a rationale
- a review date
- a disposition

## Severity Model

| Severity | Meaning |
| --- | --- |
| Blocker | Must be resolved or explicitly scoped out before the affected epic can close |
| Major | May proceed temporarily only with Project Owner acceptance and review date |
| Minor | Non-blocking but tracked to prevent silent loss |

## Debt Entries

| Debt ID | Area | Severity | Description | Source | Owner | Affects Epics | Disposition | Review Date |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| DEBT-E0-001 | ATS | Blocker | App-wide `NSAllowsArbitraryLoads` remains enabled | `Docs/AUDIT_FINDINGS_LOCAL.md` M-4 | Epic 1 owner | 0, 1, 5 | Open | 2026-06-07 |
| DEBT-E0-002 | Token Hygiene | Blocker | Token-bearing URLs still exist in watchlist, playback, and Top Shelf paths | `Docs/AUDIT_FINDINGS_LOCAL.md` M-5 and current repo findings | Epic 1 owner and Epic 4 owner | 0, 1, 2, 4, 5 | Open | 2026-06-07 |
| DEBT-E0-003 | Privacy Manifest | Blocker | No `PrivacyInfo.xcprivacy` exists yet | Repo baseline | Epic 0 steward | 0, 1, 5 | Open | 2026-06-07 |
| DEBT-E0-004 | Observability Policy Enforcement | Major | Logging remains heavily `print()`-driven and inconsistent | Current repo findings | Epic 1 owner and Epic 4 owner | 0, 1, 4, 5 | Open | 2026-06-14 |
| DEBT-E0-005 | Swift 6 Build Truth | Major | `SWIFT_VERSION = 5.0` masks concurrency debt that is already known in the audit | `Docs/AUDIT_FINDINGS_LOCAL.md` H-9 | Project Owner | 0, 4, 5 | Open | 2026-06-14 |
| DEBT-E0-006 | UI Automation Gap | Major | No formal UI regression target exists yet for Home, Preview, Detail, Playback, or Top Shelf | Epic 0 baseline | Epic 0 steward | 0, 2, 3, 4, 5 | Open | 2026-06-14 |
| DEBT-E0-007 | Accessibility Automation Gap | Major | Accessibility validation is documented but not yet automated | Epic 0 baseline | Epic 0 steward | 0, 2, 3, 4, 5 | Open | 2026-06-14 |
| DEBT-E0-008 | Performance Baseline Gap | Major | Performance budgets are defined, but no formal first-run capture set is stored yet | Epic 0 baseline | Epic 0 steward | 0, 2, 4, 5 | Open | 2026-06-14 |
| DEBT-E0-009 | ADR Index Missing Before This Slice | Minor | ADRs existed without a tracked index before this governance completion slice | Epic 0 completion work | Epic 0 steward | 0 | Resolved in current slice | 2026-05-31 |

## Debt Acceptance Rules

1. Blocker debt may not be silently carried into epic closure.
2. Major debt requires explicit Project Owner acceptance.
3. Minor debt may be accepted by the relevant reviewer if it does not weaken a gate.
4. Resolved debt remains in the register for traceability until Epic 5 closes.

## Review Requirements

- Review all open blocker and major debt weekly while Epic 0 is active.
- Re-check all open debt at the start of every delivery epic.
- Perform full debt review in Epic 5 before ship/no-ship decision.

## Acceptance Criteria

This debt register is acceptable when:

1. Current known cross-cutting debt is recorded explicitly.
2. Every entry has owner, severity, disposition, and review date.
3. Reviewers can reject unsafe closure of an epic by citing an unresolved blocker debt entry.
