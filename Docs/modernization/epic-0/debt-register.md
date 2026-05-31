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
| Governance Blocker | Prevents Epic 0 from operating because a rule, artifact, owner, or evidence model is missing or contradictory |
| Blocker | Must be resolved or explicitly scoped out before the affected epic can close |
| Major | May proceed temporarily only with Project Owner acceptance and review date |
| Minor | Non-blocking but tracked to prevent silent loss |

## Debt Types

| Type | Meaning | Epic 0 impact |
| --- | --- | --- |
| Governance blocker | A defect in the Epic 0 governance model itself | Epic 0 is not operational until resolved |
| Inherited implementation blocker | A known product, security, privacy, testing, or platform defect discovered by Epic 0 and carried into a delivery epic | Epic 0 can be operational, but the affected epic cannot close until resolved or explicitly scoped out |
| Accepted debt | A known limitation accepted for a bounded period with owner and review date | Does not block merge unless the acceptance expires or violates a gate |

## Debt Entries

| Debt ID | Area | Severity | Type | Description | Source | Owner | Affects Epics | Disposition | Review Date | Close Condition |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| DEBT-E0-001 | ATS | Blocker | Inherited implementation blocker | App-wide `NSAllowsArbitraryLoads` remains enabled | `Docs/AUDIT_FINDINGS_LOCAL.md` M-4 and `E1-PR1-SCAN-005` | Epic 1 owner | 1, 5 | Open | 2026-06-07 | ATS policy is scoped under ADR-004 and validated by security/privacy review |
| DEBT-E0-002 | Token Hygiene | Blocker | Inherited implementation blocker | Token-bearing URLs still exist in watchlist, playback, media asset, Siri/search, music, and Top Shelf-adjacent paths | `Docs/AUDIT_FINDINGS_LOCAL.md` M-5, `E1-PR1-SCAN-003`, and `E1-PR1-SCAN-006` | Epic 1 owner, Epic 2 owner, and Epic 4 owner | 1, 2, 3, 4, 5 | Open | 2026-06-07 | Token-bearing diagnostics, generated URLs, and extension payloads are eliminated or explicitly contained under ADR-002 |
| DEBT-E0-003 | Privacy Manifest | Blocker | Inherited implementation blocker | No `PrivacyInfo.xcprivacy` exists yet | Repo baseline | Epic 1 owner | 1, 5 | Open | 2026-06-07 | Initial privacy manifest and disclosure matrix review are complete |
| DEBT-E0-004 | Observability Policy Enforcement | Major | Inherited implementation blocker | Logging remains heavily `print()`-driven and inconsistent, with token-sensitive Sentry/logging surfaces still present | `E1-PR1-SCAN-004` | Epic 1 owner and Epic 4 owner | 1, 4, 5 | Open | 2026-06-14 | Changed auth/network/playback diagnostics use the observability policy and forbidden fields are removed from production sinks |
| DEBT-E0-005 | Swift 6 Build Truth | Major | Inherited implementation blocker | `SWIFT_VERSION = 5.0` masks concurrency debt that is already known in the audit | `Docs/AUDIT_FINDINGS_LOCAL.md` H-9 | Project Owner | 4, 5 | Open | 2026-06-14 | Swift version and concurrency migration decision is recorded and validated |
| DEBT-E0-006 | UI Automation Gap | Major | Accepted debt | No formal UI regression target exists yet for Home, Preview, Detail, Playback, or Top Shelf | Epic 0 baseline | Epic 0 steward | 2, 3, 4, 5 | Open | 2026-06-14 | UI automation lane exists or manual UAT evidence is accepted for affected flows |
| DEBT-E0-007 | Accessibility Automation Gap | Major | Accepted debt | Accessibility validation is documented but not yet automated | Epic 0 baseline | Epic 0 steward | 2, 3, 4, 5 | Open | 2026-06-14 | Accessibility automation exists or manual accessibility evidence is accepted for affected flows |
| DEBT-E0-008 | Performance Baseline Gap | Major | Accepted debt | Performance budgets are defined, but no formal first-run capture set is stored yet | Epic 0 baseline | Epic 0 steward | 2, 4, 5 | Open | 2026-06-14 | First performance baseline capture set is recorded or explicit Project Owner exception exists |
| DEBT-E0-009 | ADR Index Missing Before This Slice | Minor | Governance blocker | ADRs existed without a tracked index before this governance completion slice | Epic 0 completion work | Epic 0 steward | 0 | Resolved | 2026-05-31 | ADR index exists and points to accepted Epic 0 ADRs |
| DEBT-E1-PR1-001 | Token Hygiene | Blocker | Inherited implementation blocker | PR 1 token scan found 87 `X-Plex-Token` lines across 28 files, including generated URLs in provider, media, Siri/search, music, watchlist, and playback surfaces | `E1-PR1-SCAN-003` | Epic 1 owner, Epic 2 owner, and Epic 4 owner | 1, 2, 3, 4, 5 | Open | 2026-06-07 | Later Epic 1 PRs classify each token-bearing URL as header-first, contained query-token, cached opaque handoff, or downstream epic-owned remediation |
| DEBT-E1-PR1-002 | Discover/provider Containment | Blocker | Inherited implementation blocker | Discover and metadata provider endpoints remain unstable provider APIs requiring account-token query parameters | `E1-PR1-SCAN-007` | Epic 1 owner | 1, 3, 5 | Open | 2026-06-07 | Discover/watchlist adapter owns these endpoints, redacts diagnostics, and documents graceful degradation |
| DEBT-E1-PR1-003 | Legacy Endpoint Fallbacks | Blocker | Inherited implementation blocker | Legacy `plex.tv/pms/servers.xml` and legacy Home fallback paths remain present and require retirement or containment decisions | `E1-PR1-SCAN-007` | Epic 1 owner | 1, 5 | Open | 2026-06-07 | Legacy fallbacks are contained behind owned adapters and have retirement triggers after v2 parity evidence |
| DEBT-E1-PR1-004 | Live Plex Fixture Coverage | Major | Accepted debt | No approved live Plex fixture command or credentialed fixture environment exists for PR 1 evidence capture | `E1-PR1-MISS-001` | Epic 1 owner | 1, 5 | Open | 2026-06-14 | Epic 1 closure includes live UAT evidence or an accepted fixture strategy with Project Owner approval |
| DEBT-E1-PR1-005 | ATS and Trust Policy | Blocker | Inherited implementation blocker | PR 1 trust scan found app-wide arbitrary loads and custom trust delegates across Plex auth, Plex network, thumbnail, and image cache paths | `E1-PR1-SCAN-005` | Epic 1 owner | 1, 5 | Open | 2026-06-07 | Trust behavior is unified under ADR-004 with scoped exceptions, tests, and security/privacy review |
| DEBT-E1-PR1-006 | Sensitive Observability Surfaces | Major | Inherited implementation blocker | PR 1 observability scan found 27 Sentry capture call sites, 19 `stream_url` lines, and 93 scoped `print()` lines in token-sensitive areas | `E1-PR1-SCAN-004` | Epic 1 owner and Epic 4 owner | 1, 4, 5 | Open | 2026-06-14 | Changed sinks use ADR-005 taxonomy and forbidden fields are absent from logs, breadcrumbs, and Sentry extras |

## Known-Failure Register

Known failures are tracked here instead of in a separate artifact so debt, failure ownership, disposition, and review date stay in one governance surface.

| Failure ID | Related Debt | Area | Current Finding | Replacement or Required Evidence | Owner | Blocks |
| --- | --- | --- | --- | --- | --- | --- |
| KF-E0-001 | DEBT-E0-001 | ATS | App-wide arbitrary loads are enabled | Scoped ATS policy review and validation evidence | Epic 1 owner | Epic 1 close |
| KF-E0-002 | DEBT-E0-002 | Token Hygiene | Token-bearing URLs and stream URLs can reach logs, Sentry, or Top Shelf | Redaction tests, sanitized log examples, Sentry field review, Top Shelf payload review | Epic 1 owner and Epic 4 owner | Epic 1, Epic 2, and Epic 4 close as applicable |
| KF-E0-003 | DEBT-E0-003 | Privacy Manifest | No privacy manifest exists | Initial privacy manifest and disclosure review evidence | Epic 1 owner | Epic 1 close |
| KF-E0-004 | DEBT-E0-004 | Observability | Diagnostics are inconsistent and `print()`-heavy | Observability review records for changed surfaces | Epic 1 owner and Epic 4 owner | Affected work package close |
| KF-E0-005 | None | Credential Storage | Older roadmap baseline said credential-storage tests were failing | Superseded by `E0-TEST-002`; re-run targeted credential tests if credential storage changes | Epic 1 owner | No current blocker |
| KF-E1-PR1-001 | DEBT-E1-PR1-001 | Token Hygiene | Token-bearing URL construction is widespread across 28 files | Header-first transport evidence, query-token containment decisions, or downstream epic ownership records | Epic 1 owner | Epic 1 close for Epic 1-owned surfaces |
| KF-E1-PR1-002 | DEBT-E1-PR1-002 | Discover/provider APIs | Discover/provider endpoints are unstable and account-token scoped | Discover/watchlist containment evidence and graceful degradation tests | Epic 1 owner | Epic 1 close |
| KF-E1-PR1-003 | DEBT-E1-PR1-003 | Legacy APIs | Legacy plex.tv fallback endpoints remain present | Retirement trigger or containment evidence | Epic 1 owner | Epic 1 close |
| KF-E1-PR1-004 | DEBT-E1-PR1-004 | Testing/UAT | Live Plex fixture coverage is not defined | Live UAT evidence or accepted fixture strategy | Epic 1 owner | Epic 1 close if no equivalent UAT evidence exists |
| KF-E1-PR1-005 | DEBT-E1-PR1-005 | ATS/Trust | App-wide arbitrary loads and multiple custom trust delegates remain open | Scoped ATS/trust review under ADR-004 | Epic 1 owner | Epic 1 close |
| KF-E1-PR1-006 | DEBT-E1-PR1-006 | Observability | Sensitive Sentry/logging/print surfaces remain present | Sanitized logging and Sentry review evidence for changed sinks | Epic 1 owner and Epic 4 owner | Affected work package close |

## Debt Acceptance Rules

1. Governance blockers prevent Epic 0 from being operational until resolved.
2. Inherited implementation blockers may be carried into a delivery epic only when owner, affected epic, review date, and close condition are recorded.
3. Blocker debt may not be silently carried into epic closure.
4. Major debt requires explicit Project Owner acceptance.
5. Minor debt may be accepted by the relevant reviewer if it does not weaken a gate.
6. Resolved debt remains in the register for traceability until Epic 5 closes.

## Review Requirements

- Review all open blocker and major debt weekly while Epic 0 is active.
- Re-check all open debt at the start of every delivery epic.
- Perform full debt review in Epic 5 before ship/no-ship decision.

## Acceptance Criteria

This debt register is acceptable when:

1. Current known cross-cutting debt is recorded explicitly.
2. Every entry has owner, severity, type, disposition, review date, and close condition.
3. Reviewers can reject unsafe closure of an epic by citing an unresolved blocker debt entry.
4. Known failures that affect Epic 1 are represented with replacement evidence or close conditions.
