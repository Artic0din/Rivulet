# Epic 0 - Platform Foundation Charter

## Status

Accepted on 2026-05-31 as the governing charter for the Rivulet modernization program.

## Purpose

Epic 0 exists to make the rest of the modernization program safe to execute. It is the cross-cutting foundation stream that defines the standards, budgets, gates, artifacts, evidence, and review model inherited by every other epic.

Epic 0 does not primarily deliver user-facing features. Its job is to prevent avoidable regressions, privacy leaks, performance drift, accessibility debt, and unverifiable delivery.

## Objective

Make Platform Foundation operational so that Epics 1 through 5 can be executed against explicit, measurable, reviewable gates instead of implicit quality expectations.

## Source of Truth

This charter is governed by:

- `Docs/superpowers/specs/2026-05-31-rivulet-modernization-roadmap-design.md`
- `Docs/AUDIT_FINDINGS_LOCAL.md`
- The approved Epic 0 decomposition dated 2026-05-31

If a future plan conflicts with this charter, this charter wins unless it is superseded by an approved ADR and reviewed by the project owner.

## Scope

Epic 0 owns the following cross-cutting areas:

- Security
- Privacy
- Accessibility
- Testing
- Performance
- Observability
- Architecture Decision Records (ADR)

Epic 0 is responsible for:

- Defining mandatory gates for later epics
- Publishing the artifacts and templates required to satisfy those gates
- Capturing the current baseline for the repo where evidence already exists
- Defining escalation rules when gates fail
- Defining ownership and sign-off expectations
- Preventing user-facing work from outrunning the foundation needed to verify it

## Non-goals

Epic 0 does not:

- Redesign Home, Detail, or Playback user experience
- Rewrite Plex client architecture
- Choose final visual-system implementation details
- Deliver Apple TV parity by itself
- Expand the program into backend operations, SRE, incident management, on-call, runbooks, or service ownership

## Current Baseline Findings Driving This Charter

The current repository state justifies Epic 0 as an always-on stream:

1. `Rivulet/Info.plist` enables `NSAllowsArbitraryLoads = true`, which disables ATS application-wide and makes the scoped `m3u4u.com` exception redundant.
2. `Rivulet/Services/Plex/PlexWatchlistAPI.swift` places `X-Plex-Token` in query strings and logs request URLs publicly.
3. `Rivulet/Views/Player/UniversalPlayerViewModel.swift` sends `stream_url` to Sentry extras.
4. `TopShelfExtension/ContentProvider.swift` passes token-bearing image URLs to Top Shelf.
5. Initial Epic 0 baseline found no `PrivacyInfo.xcprivacy` file for the app or extension; Epic 1 PR 3 adds the baseline manifests and disclosure matrix, while Sentry, Top Shelf, ATS, local-network, and token-transport implementation debt remains tracked separately.
6. `Rivulet.xcodeproj/project.pbxproj` still sets `SWIFT_VERSION = 5.0` on all build configurations, while the codebase is already carrying Swift 6 migration debt.
7. Logging is inconsistent and heavily `print()`-driven across networking, playback, auth, and Top Shelf.
8. The repo has unit-test coverage, but no formalized UI, accessibility, or performance gate package yet.

## Operating Principles

1. No epic closes without satisfying the applicable Epic 0 gates.
2. Evidence beats assertion. A claimed result without recorded evidence does not count.
3. Security and privacy issues take precedence over parity polish.
4. Performance and accessibility are first-order product requirements, not release-week cleanup.
5. Exceptions are explicit, time-boxed, and recorded as accepted debt with owner and review date.
6. Documentation is part of the product. If the gate cannot be reviewed, it does not exist.
7. Epic 0 can be operational while implementation blockers remain open, provided those blockers are classified, owned, and carried into the affected delivery epic.
8. Governance blockers prevent the Epic 0 control plane from operating. Inherited implementation blockers prevent the affected delivery epic from closing.

## Governance Roles

| Role | Owner | Responsibilities |
| --- | --- | --- |
| Project Owner | Ryan Foyle | Final approval for gate changes, ADR acceptance, and debt acceptance |
| Epic 0 Steward | Project Owner unless delegated in writing | Maintains Epic 0 artifacts, evidence model, and gate integrity |
| Epic Owner | Assigned per epic | Delivers feature work and produces inherited Epic 0 evidence |
| Domain Reviewer | Reviewer with primary responsibility for the affected domain | Verifies security, privacy, accessibility, testing, performance, or observability evidence |
| Release Gate Reviewer | Project Owner plus at least one domain reviewer | Makes the final ship/no-ship recommendation in Epic 5 |

Ownership defaults to the Project Owner until a named owner is delegated in the relevant work package, PR, or artifact. A work package is not reviewable if ownership is left implicit.

Every Epic 1 work package must name the following reviewers before merge:

- security reviewer
- privacy reviewer
- testing reviewer
- observability reviewer

The same person may fill more than one reviewer role, but the role assignment must be explicit in the work package evidence.

## Required Artifact Set

Epic 0 is operational only when the following artifacts exist and are current:

- `Docs/modernization/epic-0/foundation-charter.md`
- `Docs/modernization/epic-0/gate-matrix.md`
- `Docs/modernization/epic-0/evidence-register.md`
- `Docs/modernization/epic-0/regression-matrix.md` including the UAT matrix
- `Docs/modernization/epic-0/debt-register.md` including the known-failure register
- `Docs/modernization/epic-0/security-network-surface-inventory.csv`
- `Docs/modernization/epic-0/privacy-disclosure-matrix.md`
- `Docs/modernization/epic-0/accessibility-validation-matrix.md`
- `Docs/modernization/epic-0/test-command-pack.md`
- `Docs/modernization/epic-0/performance-budgets-and-baseline.md`
- `Docs/modernization/epic-0/observability-policy.md`
- `Docs/modernization/epic-0/media-validation-corpus.md`
- `Docs/modernization/epic-0/parity-scorecard.md`
- `Docs/modernization/epic-0/design-review-template.md`

## Required ADR Set

Epic 0 owns these accepted ADRs:

- `Docs/adr/README.md`
- `Docs/adr/ADR-001-foundation-gate-model.md`
- `Docs/adr/ADR-002-token-transport-and-redaction-policy.md`
- `Docs/adr/ADR-003-plex-endpoint-classification-and-containment-policy.md`
- `Docs/adr/ADR-004-ats-and-trust-policy.md`
- `Docs/adr/ADR-005-observability-and-sentry-hygiene-policy.md`
- `Docs/adr/ADR-006-accessibility-validation-standard.md`
- `Docs/adr/ADR-007-performance-measurement-and-budget-model.md`

## Inherited Gate Model

Every Epic 1 through Epic 5 work package inherits the following obligations:

| Area | Required before merge | Required before epic close |
| --- | --- | --- |
| Security | No new secret leakage path; affected surfaces inventoried; reviewer sign-off | All applicable controls operational and evidenced |
| Privacy | No new undisclosed data flow; affected disclosures updated | Privacy evidence complete and reviewed |
| Accessibility | Focus path and VoiceOver behavior reviewed for changed flows | All required flows passed and evidenced |
| Testing | Required automated tests added or updated; exact commands recorded | Regression pack complete and passing |
| Performance | No unexplained budget breach; relevant metrics captured | Budget targets met or debt explicitly accepted |
| Observability | Logs/events comply with policy; no forbidden fields | Observability evidence complete and reviewed |
| Documentation | ADR updated if decision changed; evidence artifacts linked | All epic-specific evidence attached to the register, dependency assumptions documented, and known limitations recorded |

Baseline evidence may be `Captured` to start a delivery epic when it documents the current state and is linked to a gate, debt item, or known failure. Gate-satisfying evidence for epic closure must be promoted to `Gate Satisfying` unless the Project Owner records an explicit exception.

## Review Requirements

The following reviews are mandatory:

1. Any change to Epic 0 gates or ADRs requires Project Owner review.
2. Any change affecting auth, tokens, URLs, trust, or crash reporting requires a security/privacy review.
3. Any change affecting focus, overlays, playback controls, or core navigation requires an accessibility review.
4. Any change affecting launch, home, preview, or playback startup must include a performance review.
5. Any change introducing a new log, breadcrumb, crash field, or telemetry field requires an observability review.
6. Any Epic 1 work package must explicitly identify security, privacy, testing, and observability reviewers before it is eligible for merge.
7. Any release-time architecture change, release exception, or risk-acceptance decision in Epic 5 requires ADR review or an explicit ADR exemption note.

## Evidence Requirements

Evidence must be:

- Fresh for the current change
- Stored in a reviewable location
- Linked from `Docs/modernization/epic-0/evidence-register.md`
- Explicit about device, simulator, network conditions, and build used
- Sufficient for an independent reviewer to repeat the validation

Acceptable evidence includes:

- Command output with exit status
- Test result bundles
- Screenshots and video captures
- Accessibility Inspector notes
- Structured metric captures
- Linked issue references for approved exceptions

Evidence needed to begin Epic 1:

- accepted Epic 0 gate matrix and ADR set
- captured baseline evidence for security, privacy, observability, testing, and build state
- endpoint inventory entries for known Plex, Discover, Top Shelf, Sentry, ATS, and trust surfaces
- UAT coverage for Epic 1 auth, server selection, Plex Home, watchlist/discover, deep-link, and failure-state flows
- known-failure and implementation-blocker entries for unresolved ATS, token, privacy, and observability risks

Evidence needed to close Epic 1:

- reviewed evidence for every changed auth, network, endpoint, token, privacy, and observability surface
- reviewed endpoint classification and containment evidence for all Plex integration paths
- reviewed test evidence for the applicable Epic 1 command pack and UAT flows
- reviewed debt disposition for every blocker that affects Epic 1

## Gate Failure Escalation

### Severity Levels

| Severity | Definition | Required action |
| --- | --- | --- |
| Governance Blocker | Missing or contradictory Epic 0 rule, artifact, owner, or evidence model that prevents review from operating | Epic 0 cannot be treated as operational until corrected |
| Blocker | Security, privacy, accessibility, or playback-risk issue that invalidates the change | Merge blocked; owner review required; issue must be opened or fixed before progress continues |
| Major | Gate unmet but the change can proceed only with explicit short-term debt acceptance | Project Owner approval required; debt register entry required; review date required |
| Minor | Non-blocking improvement or incomplete evidence formatting | Fix before epic close; may merge only if reviewer accepts immediate follow-up |

Implementation blockers may be carried from Epic 0 into a delivery epic only when they are recorded in the debt register as inherited implementation blockers with owner, affected epic, review date, and close condition. They do not prevent Epic 0 from being operational, but they do prevent the affected delivery epic from closing.

### Escalation Path

1. Reviewer marks the failed gate and cites the artifact or evidence gap.
2. Epic owner either fixes the gate or proposes an explicit debt acceptance entry.
3. Project Owner decides whether the item is blocker, major, or accepted debt.
4. If blocker, affected workstream pauses until the gate is satisfied or scope is reduced by approved decision.
5. All accepted debt must include owner, rationale, risk, expiry date, and review trigger.

## Acceptance Criteria

Epic 0 is considered operational when all of the following are true:

1. The full Epic 0 document package exists and is internally consistent.
2. The required ADR set is accepted.
3. Every delivery epic can point to explicit inherited gates, required artifacts, and review rules.
4. The parity scorecard exists and is wired to evidence requirements.
5. The regression matrix exists and defines must-not-regress flows and UAT flows.
6. The debt register exists and records current cross-cutting debt, known failures, and inherited implementation blockers.
7. The ADR index exists and points to the accepted Epic 0 ADR set.
8. The media validation corpus exists and covers direct play, remux, HLS, HDR, Dolby Vision, Dolby Atmos, subtitles, high bitrate content, TV, movies, and Live TV.
9. The evidence register contains baseline entries drawn from the current repo findings.
10. At least one fresh verification artifact exists for each of: testing, privacy, observability, and build baseline.
11. Baseline evidence rules clearly distinguish captured evidence, reviewed evidence, superseded evidence, and gate-satisfying evidence.

## Exit Gate

Epic 0 does not “complete once.” It becomes operational when:

- Epics 1 through 4 can start delivery work without inventing their own gate model
- Reviewers can reject or accept work using this charter and the supporting artifact set
- Exceptions have a formal escalation path
- Evidence can be attached consistently and reviewed independently
- Open implementation blockers are explicitly carried into their affected epics rather than treated as unresolved Epic 0 governance gaps

## Review Cadence

- Weekly while Epic 0 is the active focus
- At the start of each new delivery epic
- At every major parity review
- Before Epic 5 ship/no-ship review

## Amendment Rules

This charter may be amended only when:

1. The change is captured in an ADR or documented change section
2. The Project Owner approves it
3. The affected Epic 0 artifacts are updated together
4. The change does not violate the approved modernization roadmap structure
