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
| DEBT-E0-001 | ATS | Blocker | Inherited implementation blocker | App-wide `NSAllowsArbitraryLoads` remains enabled and local-network privacy copy is not yet resolved | `Docs/AUDIT_FINDINGS_LOCAL.md` M-4, `E1-PR1-SCAN-005`, and `E1-PR3-LOCAL-001` | Epic 1 owner | 1, 5 | Open | 2026-06-07 | ATS policy is scoped under ADR-004 and validated by security/privacy review |
| DEBT-E0-002 | Token Hygiene | Blocker | Inherited implementation blocker | Token-bearing URLs still exist in watchlist/provider, playback, media asset, Siri/search image, and Top Shelf-adjacent paths; PR 5 migrated locally verifiable PMS playlist/music/radio/core request construction to header-first auth and explicitly contained retained query-token families | `Docs/AUDIT_FINDINGS_LOCAL.md` M-5, `E1-PR1-SCAN-003`, `E1-PR1-SCAN-006`, `E1-PR2-SCAN-001`, `E1-PR2-LOG-001`, `E1-PR3-MATRIX-001`, `E1-PR3-TOPSHELF-001`, `E1-PR5-MIGRATION-001`, `E1-PR5-CONTAIN-001`, and `E1-PR5-SCAN-001` | Epic 1 owner, Epic 2 owner, and Epic 4 owner | 1, 2, 3, 4, 5 | Open | 2026-06-07 | Token-bearing generated URLs and extension payloads are eliminated or explicitly contained under ADR-002; PR 2-sensitive diagnostics must remain redacted |
| DEBT-E0-003 | Privacy Manifest | Blocker | Inherited implementation blocker | Initial privacy manifest baseline and Epic 1 disclosure matrix were missing before PR 3 | Repo baseline, `E0-PRIV-001`, `E0-PRIV-002`, `E1-PR3-PRIV-001`, and `E1-PR3-MATRIX-001` | Epic 1 owner | 1, 5 | Resolved | 2026-05-31 | Initial app and extension privacy manifests exist, validate with `plutil`, and the disclosure matrix covers Epic 1 Plex/Sentry/Top Shelf/deep-link/local-network data paths |
| DEBT-E0-004 | Observability Policy Enforcement | Major | Inherited implementation blocker | Logging remains heavily `print()`-driven and inconsistent; PR 2 redacts high-risk changed Sentry/logging sinks, PR 4 redacts changed auth/connection diagnostics, PR 6 redacts changed Plex Home identity URL/error diagnostics, and PR 7 redacts changed server machine-identifier fetch diagnostics, but these PRs do not replace the full diagnostic system | `E1-PR1-SCAN-004`, `E1-PR2-OBS-001`, `E1-PR2-LOG-001`, `E1-PR4-SEC-001`, `E1-PR4-SCAN-001`, `E1-PR6-SCAN-001`, and `E1-PR7-SCAN-001` | Epic 1 owner and Epic 4 owner | 1, 4, 5 | Open | 2026-06-14 | Changed auth/network/playback diagnostics use the observability policy and forbidden fields are removed from production sinks |
| DEBT-E0-005 | Swift 6 Build Truth | Major | Inherited implementation blocker | `SWIFT_VERSION = 5.0` masks concurrency debt that is already known in the audit | `Docs/AUDIT_FINDINGS_LOCAL.md` H-9 | Project Owner | 4, 5 | Open | 2026-06-14 | Swift version and concurrency migration decision is recorded and validated |
| DEBT-E0-006 | UI Automation Gap | Major | Accepted debt | No formal UI regression target exists yet for Home, Preview, Detail, Playback, or Top Shelf | Epic 0 baseline | Epic 0 steward | 2, 3, 4, 5 | Open | 2026-06-14 | UI automation lane exists or manual UAT evidence is accepted for affected flows |
| DEBT-E0-007 | Accessibility Automation Gap | Major | Accepted debt | Accessibility validation is documented but not yet automated | Epic 0 baseline | Epic 0 steward | 2, 3, 4, 5 | Open | 2026-06-14 | Accessibility automation exists or manual accessibility evidence is accepted for affected flows |
| DEBT-E0-008 | Performance Baseline Gap | Major | Accepted debt | Performance budgets are defined, but no formal first-run capture set is stored yet | Epic 0 baseline | Epic 0 steward | 2, 4, 5 | Open | 2026-06-14 | First performance baseline capture set is recorded or explicit Project Owner exception exists |
| DEBT-E0-009 | ADR Index Missing Before This Slice | Minor | Governance blocker | ADRs existed without a tracked index before this governance completion slice | Epic 0 completion work | Epic 0 steward | 0 | Resolved | 2026-05-31 | ADR index exists and points to accepted Epic 0 ADRs |
| DEBT-E1-PR1-001 | Token Hygiene | Blocker | Inherited implementation blocker | PR 1 token scan found 87 runtime `X-Plex-Token` lines across 28 files, including generated URLs in provider, media, Siri/search, music, watchlist, and playback surfaces; PR 5 reduces source `X-Plex-Token` lines to 79 by migrating PMS playlist/music genre/radio request construction to header-first while retaining explicitly contained query-token paths | `E1-PR1-SCAN-003`, `E1-PR2-SCAN-001`, `E1-PR5-MIGRATION-001`, `E1-PR5-CONTAIN-001`, and `E1-PR5-SCAN-001` | Epic 1 owner, Epic 2 owner, and Epic 4 owner | 1, 2, 3, 4, 5 | Open | 2026-06-07 | Later Epic 1 PRs classify each remaining token-bearing URL as header-first, contained query-token, cached opaque handoff, or downstream epic-owned remediation |
| DEBT-E1-PR1-002 | Discover/provider Containment | Blocker | Inherited implementation blocker | Discover and metadata provider endpoints remain unstable provider APIs requiring account-token query parameters pending live Plex fixture evidence; PR 5 intentionally retains query-token behavior and records containment | `E1-PR1-SCAN-007`, `E1-PR5-CONTAIN-001`, and `E1-PR5-SCAN-001` | Epic 1 owner | 1, 3, 5 | Open | 2026-06-07 | Discover/watchlist adapter owns these endpoints, redacts diagnostics, and documents graceful degradation |
| DEBT-E1-PR1-003 | Legacy Endpoint Fallbacks | Blocker | Inherited implementation blocker | Legacy `plex.tv/pms/servers.xml` and legacy Home fallback paths remain present and require retirement or containment decisions; PR 7 contains `/pms/servers.xml` usage to machine-identifier enrichment and prevents duplicate display names from becoming stable server identity keys | `E1-PR1-SCAN-007`, `E1-PR7-IDENTITY-001`, and `E1-PR7-SCAN-001` | Epic 1 owner | 1, 5 | Open | 2026-06-07 | Legacy fallbacks are contained behind owned adapters and have retirement triggers after v2 parity evidence |
| DEBT-E1-PR1-004 | Live Plex Fixture Coverage | Major | Accepted debt | No approved live Plex fixture command or credentialed fixture environment exists for PR 1 evidence capture; PR 6 adds unit coverage for Home identity/profile switching and PR 7 adds unit coverage for multi-server selection/connection ordering, but live PMS/Home/multi-server validation remains unavailable | `E1-PR1-MISS-001`, `E1-PR6-TEST-001`, and `E1-PR7-TEST-001` | Epic 1 owner | 1, 5 | Open | 2026-06-14 | Epic 1 closure includes live UAT evidence or an accepted fixture strategy with Project Owner approval |
| DEBT-E1-PR1-005 | ATS and Trust Policy | Blocker | Inherited implementation blocker | PR 1 trust scan found app-wide arbitrary loads and custom trust delegates across Plex auth, Plex network, thumbnail, and image cache paths; PR 3 documents privacy implications and PR 7 rechecks trust boundaries, but neither changes runtime trust behavior | `E1-PR1-SCAN-005`, `E1-PR3-LOCAL-001`, and `E1-PR7-TRUST-001` | Epic 1 owner | 1, 5 | Open | 2026-06-07 | Trust behavior is unified under ADR-004 with scoped exceptions, tests, and security/privacy review |
| DEBT-E1-PR1-006 | Sensitive Observability Surfaces | Major | Inherited implementation blocker | PR 1 observability scan found 27 Sentry capture call sites, 19 `stream_url` lines, and 93 scoped `print()` lines in token-sensitive areas; PR 2 removed raw stream/media URL emissions from changed Sentry extras, breadcrumbs, and selected prints; PR 4 redacts changed auth URL/error diagnostics; PR 6 redacts changed Plex Home identity error/URL diagnostics; PR 7 redacts changed machine-identifier fetch diagnostics while leaving broader print migration open | `E1-PR1-SCAN-004`, `E1-PR2-SCAN-001`, `E1-PR2-OBS-001`, `E1-PR2-LOG-001`, `E1-PR4-SEC-001`, `E1-PR4-SCAN-001`, `E1-PR6-SCAN-001`, and `E1-PR7-SCAN-001` | Epic 1 owner and Epic 4 owner | 1, 4, 5 | Open | 2026-06-14 | Changed sinks use ADR-005 taxonomy and forbidden fields are absent from logs, breadcrumbs, and Sentry extras |
| DEBT-E1-PR2-001 | Sentry Configuration Ownership | Major | Inherited implementation blocker | Release Sentry DSN is supplied by ignored compile-time `Rivulet/Config/Secrets.swift`; if a fork copies an inherited DSN, non-Debug builds can report to the inherited Sentry project | `E1-PR2-OBS-001` and `E1-PR3-SENTRY-001` | Project Owner and Epic 1 owner | 1, 5 | Open | 2026-06-14 | Sentry project ownership is confirmed, DSN provisioning is documented, or Release Sentry startup is explicitly disabled before release validation |
| DEBT-E1-PR3-001 | Local Network Privacy Disclosure | Major | Inherited implementation blocker | Rivulet connects to local PMS and Live TV devices, but PR 3 scan found no `NSLocalNetworkUsageDescription` or `NSBonjourServices` declaration in `Rivulet/Info.plist` | `E1-PR3-LOCAL-001` | Epic 1 owner | 1, 5 | Open | 2026-06-14 | Platform-appropriate local-network usage description and Bonjour declaration decision is implemented or documented as a reviewed tvOS non-requirement before Epic 1 closure or release validation |

## Known-Failure Register

Known failures are tracked here instead of in a separate artifact so debt, failure ownership, disposition, and review date stay in one governance surface.

| Failure ID | Related Debt | Area | Current Finding | Replacement or Required Evidence | Owner | Blocks |
| --- | --- | --- | --- | --- | --- | --- |
| KF-E0-001 | DEBT-E0-001 | ATS | App-wide arbitrary loads are enabled | Scoped ATS policy review and validation evidence | Epic 1 owner | Epic 1 close |
| KF-E0-002 | DEBT-E0-002 | Token Hygiene | Retained token-bearing URLs remain in playback, media asset, Top Shelf, Siri/search image, Discover/provider, and stream-selection paths | Redaction tests, sanitized log examples, Sentry field review, Top Shelf payload review, header-first migration evidence, and query-token containment evidence | Epic 1 owner and Epic 4 owner | Epic 1, Epic 2, and Epic 4 close as applicable |
| KF-E0-003 | DEBT-E0-003 | Privacy Manifest | Initial app and extension privacy manifest baseline was missing before PR 3 | Resolved by `E1-PR3-PRIV-001` and `E1-PR3-MATRIX-001`; future privacy changes still require matrix and manifest review | Epic 1 owner | No current blocker |
| KF-E0-004 | DEBT-E0-004 | Observability | Diagnostics are inconsistent and `print()`-heavy; PR 4 auth diagnostics, PR 6 Plex Home identity diagnostics, and PR 7 server discovery diagnostics are redacted for changed surfaces, but broad logging remains implementation debt | Observability review records for changed surfaces, including `E1-PR4-SEC-001`, `E1-PR6-SCAN-001`, and `E1-PR7-SCAN-001` | Epic 1 owner and Epic 4 owner | Affected work package close |
| KF-E0-005 | None | Credential Storage | Older roadmap baseline said credential-storage tests were failing | Superseded by `E0-TEST-002`; re-run targeted credential tests if credential storage changes | Epic 1 owner | No current blocker |
| KF-E1-PR1-001 | DEBT-E1-PR1-001 | Token Hygiene | Token-bearing URL construction remains after PR 5, with migrated PMS playlist/music/radio paths and retained query-token families explicitly tracked | Header-first transport evidence, query-token containment decisions, or downstream epic ownership records | Epic 1 owner | Epic 1 close for Epic 1-owned surfaces |
| KF-E1-PR1-002 | DEBT-E1-PR1-002 | Discover/provider APIs | Discover/provider endpoints are unstable and account-token scoped; PR 5 retains query-token behavior pending live evidence | Discover/watchlist containment evidence and graceful degradation tests | Epic 1 owner | Epic 1 close |
| KF-E1-PR1-003 | DEBT-E1-PR1-003 | Legacy APIs | Legacy plex.tv fallback endpoints remain present; PR 7 contains `/pms/servers.xml` usage to machine-ID enrichment only | Retirement trigger or containment evidence, including duplicate-safe server identity evidence from `E1-PR7-IDENTITY-001` | Epic 1 owner | Epic 1 close |
| KF-E1-PR1-004 | DEBT-E1-PR1-004 | Testing/UAT | Live Plex fixture coverage is not defined; PR 6 adds unit coverage for Plex Home identity/profile switching and PR 7 adds unit coverage for multi-server selection, but neither provides live PMS/Home/multi-server evidence | Live UAT evidence or accepted fixture strategy | Epic 1 owner | Epic 1 close if no equivalent UAT evidence exists |
| KF-E1-PR1-005 | DEBT-E1-PR1-005 | ATS/Trust | App-wide arbitrary loads and multiple custom trust delegates remain open after PR 7 trust-boundary review | Scoped ATS/trust review under ADR-004 | Epic 1 owner | Epic 1 close |
| KF-E1-PR1-006 | DEBT-E1-PR1-006 | Observability | Sensitive Sentry/logging/print surfaces remain present; PR 2 reduces raw URL emission, PR 4 redacts changed auth diagnostics, PR 6 redacts changed Plex Home identity diagnostics, and PR 7 redacts changed server discovery diagnostics but does not complete full logging migration | Sanitized logging and Sentry review evidence for changed sinks, including `E1-PR4-SEC-001`, `E1-PR6-SCAN-001`, and `E1-PR7-SCAN-001` | Epic 1 owner and Epic 4 owner | Affected work package close |
| KF-E1-PR2-001 | DEBT-E1-PR2-001 | Observability | Sentry DSN ownership is compile-time and local-config dependent | Release configuration review, project ownership confirmation, or explicit Release Sentry disablement evidence | Project Owner and Epic 1 owner | Epic 5 release gate and any Epic 1 release-candidate build |
| KF-E1-PR3-001 | DEBT-E1-PR3-001 | Local Network Privacy | Local network access is used, but purpose string and Bonjour declaration decision are not yet resolved | Reviewed platform-specific Info.plist decision or accepted tvOS non-requirement evidence | Epic 1 owner | Epic 1 close if local-network privacy copy remains ambiguous |

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
