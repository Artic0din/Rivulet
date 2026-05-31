# Epic 0 Regression Matrix

## Purpose

This matrix defines the must-not-regress product flows for the Rivulet modernization program. It is the authoritative baseline for manual and automated regression obligations until more complete UI automation exists.

## Rules

1. Any epic that changes a listed flow must re-run the required validation.
2. A regression on a primary flow is a blocker unless the affected scope is explicitly removed from the shipping plan.
3. Evidence must cite exact commands, screenshots, videos, or manual validation records.

## Regression Status Values

| Status | Meaning |
| --- | --- |
| Verified | Flow was validated successfully for the current change |
| Not Revalidated | Flow applies but has not been re-run for the current change |
| Gap | Required automated or manual validation path is missing |
| Deferred by Scope | Flow intentionally excluded by approved scope decision |

## Flow Matrix

| Flow ID | Flow | Why It Matters | Required Validation | Automation Status | Owning Epic | Current Baseline |
| --- | --- | --- | --- | --- | --- | --- |
| REG-001 | Auth by Plex PIN | Entry to the entire product | Targeted auth tests, manual sign-in flow, error-state review | Partial | Epic 1 | Baseline feature exists |
| REG-002 | Server discovery and selection | Foundational connectivity behavior | Targeted network/auth tests, manual selection flow | Partial | Epic 1 | Baseline feature exists |
| REG-003 | Plex Home user switching | User identity and permissions correctness | Manual switch flow, PIN path validation, watch-state spot check | Manual | Epic 1 | Baseline feature exists |
| REG-004 | Launch to Home | First impression and shell stability | Launch capture, focus validation, performance metric | Manual | Epic 2 | Baseline feature exists |
| REG-005 | Continue Watching resume from Home | High-value home interaction | Manual resume flow, playback startup evidence, watch-progress verification | Manual | Epic 2 and Epic 4 | Baseline feature exists |
| REG-006 | Library browse and pagination | Core content browsing | Manual library traversal, pagination validation, focus notes | Manual | Epic 2 and Epic 3 | Baseline feature exists |
| REG-007 | Search and result navigation | Content retrieval and deep navigation | Targeted search/deep-link tests plus manual browse | Partial | Epic 2 and Epic 3 | Baseline feature exists |
| REG-008 | Poster -> Preview -> Detail | Core Apple TV-like browsing path | Preview expansion recording, detail handoff validation, accessibility notes | Manual | Epic 3 | Strong baseline, not yet formally gated |
| REG-009 | Detail page primary actions | Playback and related-content entry from detail | Manual validation, focus path, playback handoff check | Manual | Epic 3 and Epic 4 | Baseline feature exists |
| REG-010 | Watchlist and Discover actions | Provider/discover integration behavior | Targeted watchlist tests plus manual action validation | Partial | Epic 1 and Epic 3 | Baseline feature exists with unstable endpoint risk |
| REG-011 | AVPlayer direct playback | Native playback reliability | Media corpus run with direct-play sample IDs | Partial | Epic 4 | Baseline feature exists |
| REG-012 | Local remux playback | Key non-native compatibility path | Media corpus run with remux sample IDs | Partial | Epic 4 | Baseline feature exists |
| REG-013 | HLS playback and fallback | Fallback reliability | Media corpus run with HLS sample IDs and failure-recovery validation | Partial | Epic 4 | Baseline feature exists |
| REG-014 | Audio and subtitle track selection | Accessibility and playback correctness | Media corpus track-selection scenarios, manual UI validation | Partial | Epic 4 | Baseline feature exists |
| REG-015 | Playback exit and focus restoration | User trust and navigation continuity | Manual exit path validation with focus return proof | Manual | Epic 4 | Baseline feature exists |
| REG-016 | Deep links and `NSUserActivity` restoration | Search and cross-surface continuity | Targeted Siri/deep-link tests plus manual entry flow | Partial | Epic 2 and Epic 5 | Baseline feature exists |
| REG-017 | Top Shelf launch into content | System integration and security-sensitive surface | Top Shelf screenshot set, deep-link validation, token-safety review | Manual | Epic 2 | Baseline exists with security debt |
| REG-018 | Settings navigation | Configuration safety and discoverability | Manual focus and descriptor review | Manual | Epic 2 and Epic 5 | Baseline feature exists |
| REG-019 | Live TV sample playback | Current product surface still present in repo | Media corpus Live TV sample runs, launch and exit validation | Manual | Epic 4 | Baseline feature exists |
| REG-020 | Failure-state messaging and recovery | Prevents silent or confusing breakage | Manual validation of auth, browse, preview, and playback errors | Manual | Epics 1, 2, 3, 4 | Baseline not yet consistently documented |

## Minimum Revalidation by Epic

### Epic 1

- REG-001
- REG-002
- REG-003
- REG-010
- REG-016
- REG-020

### Epic 2

- REG-004
- REG-005
- REG-006
- REG-007
- REG-016
- REG-017
- REG-018

### Epic 3

- REG-006
- REG-007
- REG-008
- REG-009
- REG-010
- REG-020

### Epic 4

- REG-005
- REG-011
- REG-012
- REG-013
- REG-014
- REG-015
- REG-019
- REG-020

### Epic 5

- Full matrix

## Evidence Template

```markdown
## Regression Record

- Flow ID:
- Date:
- Build:
- Device:
- Validation mode: automated / manual / mixed
- Result:
- Evidence link:
- Notes:
```

## Acceptance Criteria

This matrix is acceptable when:

1. It covers the primary product flows that later epics can break.
2. Each flow defines required validation and owning epic.
3. Reviewers can use it to decide whether regression coverage is sufficient.
