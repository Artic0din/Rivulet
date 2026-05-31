# Design Review Template

Use this template for every meaningful user-facing screen or flow change in any delivery epic, including Epic 1 auth, server-selection, Plex Home, watchlist/discover, deep-link, and failure-state changes.

---

## Design Review Record

- Review ID:
- Date:
- Epic:
- Screen or flow:
- Change owner:
- Reviewers:
- Applicable gate IDs:
- Related debt or known-failure IDs:

## Objective

- User problem being solved:
- Product objective:
- Parity objective:
- Dependency assumptions:
- Known limitations:

## Before State

- Before screenshots:
- Before video capture:
- Current blocking issues:

## After State

- After screenshots:
- After video capture:
- Key changes introduced:

## Focus Path

- Entry point:
- Default focus target:
- Primary navigation path:
- Exit path:
- Menu/back behavior:
- Focus restoration behavior:

## Accessibility Considerations

- VoiceOver order:
- Focus accessibility:
- Reduced motion impact:
- Contrast considerations:
- Text truncation or readability risks:
- Accessibility validation result:

## Security and Privacy Considerations

- Token-bearing surfaces affected:
- User or server data affected:
- Deep-link, Top Shelf, or extension payload impact:
- Sentry/logging impact:
- Privacy disclosure impact:
- Security/privacy review result:

## Performance Considerations

- Surfaces affected:
- Metrics affected:
- Before measurements:
- After measurements:
- Budget status:

## Review Notes

- Visual hierarchy:
- Motion and transition quality:
- Consistency with canonical design language:
- Edge cases reviewed:

## Evidence

- Linked evidence register entries:
- Media samples used if playback-related:
- UAT records used:
- Device and build used:

## Reviewer Sign-off

| Reviewer | Domain | Decision | Notes |
| --- | --- | --- | --- |
|  | Product | Approve / Changes required |  |
|  | Security | Approve / Changes required / Not applicable |  |
|  | Privacy | Approve / Changes required / Not applicable |  |
|  | Accessibility | Approve / Changes required |  |
|  | Performance | Approve / Changes required |  |
|  | Testing | Approve / Changes required |  |
|  | Observability | Approve / Changes required / Not applicable |  |

## Acceptance Decision

- Final decision: Accepted / Accepted with debt / Rejected
- Blocking issues remaining:
- Debt accepted:
- Dependency assumptions accepted:
- Known limitations accepted:
- Required follow-up:

---

## Review Checklist

- [ ] Screen or flow objective is explicit
- [ ] Before and after evidence included
- [ ] Parity objective stated
- [ ] Applicable Epic 0 gates identified
- [ ] Security and privacy considerations documented
- [ ] Focus path documented
- [ ] Accessibility considerations documented
- [ ] Performance considerations documented
- [ ] Dependency assumptions documented
- [ ] Known limitations documented
- [ ] Reviewers signed off
- [ ] Acceptance decision recorded
