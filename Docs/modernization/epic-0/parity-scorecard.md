# Apple TV Parity Scorecard

## Framework

Rivulet uses a five-point parity scale:

| Score | Meaning |
| --- | --- |
| 1 | Fundamentally incomplete or unreliable |
| 2 | Present but obviously below shipping quality |
| 3 | Competent baseline with visible gaps |
| 4 | High-quality and near-target |
| 5 | Premium, cohesive, and ready to represent the target experience |

The scorecard is not a vanity metric. Each category requires evidence and cannot be upgraded without proof.

## Scorecard

| Category | Current Score | Target Score | Evidence Required | Blocking Issues | Owning Epic | Acceptance Criteria |
| --- | --- | --- | --- | --- | --- | --- |
| Home | 3 | 5 | Launch video, home screenshots, focus-path validation, performance capture for time to first useful screen and home render | Home is still row-first instead of hero-first; loading/error states are not yet normalized; no formal home evidence pack | Epic 2 | Launch lands in a coherent hero-first experience, Continue Watching is prominent, and home passes focus, performance, and accessibility checks |
| Hero | 2 | 5 | Hero screenshots, interaction capture, resume/play action review, logo rendering review | Hero exists but is not canonical; dynamic updates and action hierarchy are not yet formalized | Epic 2 | Home hero is the primary launch surface with stable metadata, artwork, logo, resume/play actions, and deterministic focus behavior |
| Navigation | 3 | 5 | Sidebar video capture, remote behavior notes, deep-link re-entry validation | Sidebar/content rules are partially implicit; Siri Remote behavior is not yet formalized end-to-end | Epic 2 | Top-level navigation is deterministic with Menu/back behavior, deep-link entry, and section changes behaving consistently |
| Focus | 3 | 5 | Focus path diagrams, overlay enter/exit capture, Accessibility Inspector notes | Focus restoration depends on local behavior rather than a documented standard; no formal gate yet | Epic 2 | Sidebar, rows, preview, detail, overlays, and player all restore and transfer focus without loss or dead ends |
| Preview | 4 | 5 | Poster -> preview expansion recordings, frame timing notes, accessibility validation | Preview architecture is strong but not yet governed by performance and motion rules; no formal evidence pack | Epic 3 | Preview expansion, paging, metadata reveal, and exit path feel native, fast, and stable across representative content |
| Detail | 3 | 5 | Detail screenshots, metadata hierarchy review, related-content validation | Detail density and hierarchy are inconsistent; universal details are not yet defined | Epic 3 | Detail pages present a unified hierarchy, related content, watch options, and correct focus and playback handoff behavior |
| Playback | 3 | 5 | Media-corpus-backed playback runs, startup/seek metrics, interruption recovery evidence | Stream URLs leak to Sentry, playback telemetry policy is incomplete, AVKit-first policy not yet formalized | Epic 4 | Direct play, remux, HLS, interruption recovery, track changes, and resume are reliable across the validation corpus |
| Visual Language | 3 | 5 | Screen comparison set, design review records, typography/material review | Strong isolated surfaces exist, but a single canonical visual system is not yet enforced app-wide | Epic 3 | Home, preview, detail, settings, and supporting flows share one deliberate design language with consistent hierarchy and materials |
| Top Shelf | 2 | 4 | Top Shelf screenshots, cache payload review, deep-link validation, token-safety proof | Extension currently uses token-bearing image URLs and informal cache diagnostics | Epic 2 | Top Shelf is secure, accurate, deep-links correctly, and does not leak secrets through URLs or logs |
| Accessibility | 2 | 5 | VoiceOver runs, focus accessibility validation, reduced-motion review, contrast notes | No formal app-wide validation matrix yet; current flows lack consistent evidence and sign-off | Epic 0 and inherited by Epics 2, 3, 4, 5 | Core flows pass VoiceOver, focus accessibility, reduced motion, contrast, and exit behavior validation on device |

## Score Change Rules

1. A score may only change when new evidence is added to the evidence register.
2. A category may not exceed score 4 if any blocker issue remains open in that category.
3. Accessibility may not be treated as “implicitly covered” by another category.
4. Epic 5 must review all score changes before ship/no-ship decision.

## Required Evidence by Category

### Home

- Launch capture from cold launch
- Home capture from warm launch
- Focus validation across hero and first three rows
- Time to first useful screen measurement

### Hero

- Static screenshot set
- Dynamic update recording
- Play/resume action validation
- Logo and backdrop composition review

### Navigation

- Sidebar navigation recording
- Deep-link entry and return capture
- Menu/back handling notes

### Focus

- Focus path map
- Overlay entry/exit validation
- Accessibility Inspector notes

### Preview

- Preview expansion recording
- Paging recording
- Exit and focus-restore recording
- Performance capture for time to first motion

### Detail

- Detail page comparison set
- Related content behavior capture
- Trailer launch and return validation

### Playback

- Media validation corpus evidence
- Playback startup and seek timings
- Error and recovery evidence

### Visual Language

- Comparative screen set across major surfaces
- Design review records
- Reviewer sign-off for typography, spacing, materials, motion, and hierarchy

### Top Shelf

- Extension screenshots
- Cache payload review
- Secure image transport review
- Deep-link result validation

### Accessibility

- VoiceOver validation records
- Reduced motion validation
- Contrast notes
- Focus accessibility validation across all primary flows

## Review Requirements

- Epic owner proposes score change with linked evidence.
- Domain reviewer validates the evidence.
- Project Owner accepts the score change.
- Epic 5 performs final review of all categories before release decision.
