# Rivulet Modernization Roadmap Design

## Goal

Restructure the Rivulet modernization program around product epics plus a cross-cutting platform foundation stream, so delivery matches how a real client-app product team would execute the work instead of treating quality, privacy, performance, accessibility, and release readiness as a late-stage phase.

The target product remains a distinct Plex-backed tvOS client that feels close to the Apple TV app in polish, focus behavior, content presentation, and playback quality without copying Apple branding, trade dress, or private integrations.

## Why This Design

The earlier roadmap was logically sequenced, but still too phase-oriented:

1. architecture
2. Plex
3. home
4. detail
5. playback
6. quality

That structure understates how cross-cutting constraints actually work in Rivulet:

- security affects Plex, Top Shelf, and playback URLs
- privacy affects logging, Sentry, and auth transport
- performance affects home, preview, and playback decisions
- accessibility affects focus, motion, overlays, and detail layouts
- testing and observability affect every acceptance gate

Rivulet is also a client application, not an operated backend platform. That means the program should optimize for shipping a high-quality tvOS app, not for inventing backend-style SRE or operational-process work that does not materially improve the product.

## Current Product Baseline

The roadmap is grounded in the current repository state:

- SwiftUI tvOS shell already exists in `Rivulet/ContentView.swift` and `Rivulet/Views/TVNavigation/TVSidebarView.swift`.
- Home, preview, detail, and playback systems are already sophisticated enough that this is a modernization effort, not a rewrite.
- Playback already mixes AVKit and custom FFmpeg-driven paths through `ContentRouter`, `NativePlayerViewController`, and `RivuletPlayer`.
- The repo currently has real platform debt that justifies a foundation stream:
  - permissive ATS in `Rivulet/Info.plist`
  - token-bearing URLs and public logging in Plex/watchlist/playback paths
  - no privacy manifest
  - mixed documented Plex APIs, provider/discover endpoints, and legacy XML fallback behavior
  - test baseline already red for credential storage

## Design Principles

- Rivulet remains Plex-first.
- Apple TV app feel is the UX benchmark, not a cloning target.
- Quality concerns start on day one and remain active throughout the program.
- Product epics own user-facing change.
- Platform Foundation owns gates, budgets, safety rules, and validation artifacts.
- Release Readiness is a formal ship gate, not the first time quality is evaluated.
- Backend-style operational scaling work is out of scope for the core modernization program.

## Out of Scope

The roadmap does not include:

- Apple-owned assets, naming, or visual impersonation
- private Apple APIs
- unsupported claims of Apple TV app, Up Next, or universal search integration
- backend SRE processes such as on-call rotations, service ownership matrices, or incident-runbook programs
- iPhone/iPad delivery as part of the core modernization program

Mobile expansion remains a later feasibility stream after tvOS modernization is stable.

## Approved Program Structure

### Epic 0 - Platform Foundation

This is a cross-cutting stream that starts first and remains active throughout the program.

It owns:

- security
- privacy
- accessibility
- testing
- performance
- observability

It does not exist to deliver a visible redesign by itself. Its purpose is to define the rules and evidence every other epic must satisfy before closing.

### Epic 1 - Plex Platform Modernisation

Goal: make Plex integration production-grade.

Primary areas:

- authentication and credential handling
- endpoint classification and adapter boundaries
- JSON-first response strategy
- legacy endpoint retirement or containment
- multi-server correctness
- home-user correctness
- watch state and timeline ownership
- discover/watchlist isolation and graceful degradation

### Epic 2 - Apple TV Home Experience

Goal: make Rivulet feel Apple TV-like from first launch.

Primary areas:

- hero-first home
- continue watching prominence and redesign
- featured and discovery rows
- loading, empty, and error states
- focus normalization
- Siri Remote behavior
- sidebar refinement
- secure Top Shelf integration

### Epic 3 - Apple TV Content Experience

Goal: make browsing content feel first-party.

Primary areas:

- preview transitions and poster expansion
- metadata reveal and motion refinement
- focus restoration
- detail-page hierarchy
- unified visual system
- watchlist/discover presentation
- universal details
- more ways to watch
- trailer support

### Epic 4 - Playback Excellence

Goal: make playback effectively invisible to the user.

Primary areas:

- AVKit-first and AVPlayerViewController-first policy
- RPlayer fallback strategy
- Dolby Vision and HDR capability handling
- subtitle and audio behavior
- resume/session correctness
- watch-state correctness
- interruption and failure recovery
- playback telemetry

### Epic 5 - Release Readiness and Production Validation

Goal: formal ship/no-ship decision for the tvOS client.

Primary areas:

- full regression validation
- accessibility validation
- privacy and ATS validation
- performance validation
- TestFlight validation
- App Store readiness
- architecture and testing documentation
- known limitations
- debt register and risk acceptance decisions

### Optional Epic 6 - Post-Launch Hardening

Optional and explicitly outside the core modernization roadmap.

Possible areas:

- crash review
- telemetry review
- user feedback review
- incremental polish

This should not block the main modernization program.

## Execution Model

The program runs as overlapping waves, not six serial phases.

### Wave 0 - Foundation Setup

Establish the minimum control plane needed for safe delivery:

- security rules
- token redaction policy
- ATS and privacy inventory
- failing-test baseline
- instrumentation plan
- accessibility validation checklist
- release evidence model

This is intentionally short. It exists to enable safe delivery, not to consume the program.

### Wave 1 - Plex Platform First

Epic 1 begins first because auth transport, endpoint containment, multi-server behavior, timeline reporting, and discover/watchlist ownership affect every downstream surface.

### Wave 2 - Home Experience Plus Playback Risk Reduction

Epic 2 becomes the first major user-facing delivery lane.

Epic 4 starts in parallel at the risk-reduction level:

- route audit
- AVKit-first policy definition
- HDR and Dolby Vision validation matrix
- recovery behavior design
- telemetry requirements

This gives the program the highest immediate perception gain without letting playback risk sit untouched.

### Wave 3 - Content Experience Plus Core Playback Delivery

Epic 3 and the main implementation body of Epic 4 run together.

That pairing reflects the product reality that poster, preview, detail, availability, player handoff, and resume semantics are tightly connected.

### Wave 4 - Ship Gate

Epic 5 becomes the formal production-validation pass after Epics 1 through 4 are functionally complete and have already been satisfying Epic 0 requirements during development.

## Epic Contract Model

Each epic must be defined by the same four-part contract:

- goal
- allowed scope
- blocked dependencies
- exit gate

This prevents the roadmap from turning into a loose list of tasks.

### Epic 0 Contract

Goal:
Define the cross-cutting standards, budgets, and validation model for the full program.

Allowed scope:

- ATS and privacy controls
- auth and token handling rules
- logging and Sentry sanitization rules
- test strategy
- performance budgets
- accessibility validation structure
- observability rules

Blocked dependencies:
None. This starts first.

Exit gate:
Epic 0 is not “completed once.” It becomes operational when other epics can inherit measurable gates and evidence requirements from it.

### Epic 1 Contract

Goal:
Make Plex integration safe, classified, and production-grade.

Allowed scope:

- auth transport
- token lifecycle
- adapter boundaries
- endpoint inventory and classification
- multi-server and home-user correctness
- timeline and watch-state ownership
- discover/watchlist containment

Blocked dependencies:

- Epic 0 baseline security, observability, and testing rules must exist

Exit gate:

- no token leaks
- no undocumented endpoint usage without containment
- every Plex integration path classified and owned

### Epic 2 Contract

Goal:
Make launch and top-level navigation feel premium and Apple TV-like.

Allowed scope:

- hero-first home
- row strategy
- continue watching prominence
- sidebar refinement
- focus normalization
- Siri Remote behavior
- Top Shelf

Blocked dependencies:

- Epic 1 must provide stable home data contracts and baseline token/privacy hygiene

Exit gate:

- app launch experience clearly feels Apple TV-like
- focus and top-level navigation behave deterministically in UAT

### Epic 3 Contract

Goal:
Make content browsing, expansion, and selection feel first-party.

Allowed scope:

- preview behavior
- detail hierarchy
- universal details
- availability surfaces
- discover/watchlist presentation
- motion/material/typography system

Blocked dependencies:

- stable metadata and availability contracts from Epic 1
- stable top-level navigation rules from Epic 2

Exit gate:

- poster to preview to detail flow is polished, coherent, and stable

### Epic 4 Contract

Goal:
Make playback invisible and trustworthy across the library.

Allowed scope:

- AVKit-first playback policy
- fallback rules
- HDR and Dolby Vision handling
- resume and session correctness
- interruption recovery
- playback telemetry

Blocked dependencies:

- Epic 1 must stabilize auth transport, route ownership, and timeline semantics
- Epic 0 must define playback budgets and sanitization rules

Exit gate:

- playback confidence across direct, remux, fallback, and interruption scenarios

### Epic 5 Contract

Goal:
Produce a formal release-readiness and production-validation decision.

Allowed scope:

- regression validation
- accessibility validation
- security and privacy validation
- ATS audit
- performance audit
- TestFlight validation
- App Store readiness
- docs and known limitations
- debt register and risk acceptance

Blocked dependencies:

- Epics 1 through 4 must be functionally complete
- Epic 0 artifacts and gates must already exist

Exit gate:

- explicit documented ship or no-ship decision

## Validation and Artifact Model

Epic 0 produces the reusable gates and artifacts inherited by every delivery epic.

### Security Baseline Artifacts

- token policy
- redaction rules
- ATS inventory
- privacy-manifest inventory
- logging and Sentry sanitization rules

### Quality Baseline Artifacts

- unit, integration, regression, and UAT matrix
- current known-failure register
- per-epic test obligations

### Performance Baseline Artifacts

- launch, home, preview, memory, and playback budgets
- measurement method for each budget
- evidence collection format

### Accessibility Baseline Artifacts

- VoiceOver checklist
- focus accessibility checklist
- motion-reduction checklist
- contrast and readability checklist

### Observability Baseline Artifacts

- allowed logging model
- forbidden logging model
- per-epic evidence expectations

### Common Epic Closure Requirements

Epics 1 through 4 close only when all of the following are true:

- user-visible outcome is delivered
- dependency assumptions are documented
- regression pack is passed
- relevant security and privacy checks are passed
- relevant performance budgets are met
- accessibility sign-off is completed
- known limitations are explicitly recorded

### Epic 5 Ship Packet

Epic 5 formalizes the final ship packet:

- full regression sign-off
- privacy, ATS, token, and logging audit
- final performance audit
- TestFlight validation evidence
- App Store submission readiness
- architecture, testing, and limitations documentation
- debt register and explicit risk acceptance decisions

## Repo-Specific Design Implications

This structure is specifically appropriate for the current Rivulet codebase.

### Why Epic 1 Must Start First

Current code already mixes:

- official PMS endpoints
- `plex.tv` account and home-user endpoints
- provider/discover watchlist endpoints
- legacy XML fallback behavior

That means the product cannot safely refine home, preview, detail, and playback indefinitely without first stabilizing the Plex platform layer.

### Why Home Comes Before Deep Content Work

The fastest path to perceived Apple TV parity is first-launch quality:

- hero-first home
- continue watching prominence
- premium row composition
- stable focus and remote behavior

That creates immediate perception gains while deeper preview/detail work is still in progress.

### Why Playback Cannot Wait Until the End

Playback is the highest technical-risk lane in the app.

Rivulet already contains:

- AVKit-native routes
- custom sample-buffer routes
- local remux logic
- HLS fallback logic
- HDR and Dolby Vision routing behavior

That risk demands early investigation, validation, and telemetry design even if the bulk of playback delivery lands after platform stabilization.

### Why Epic 5 Is a Client-App Ship Gate

Rivulet is not an operated backend product.

Epic 5 therefore stays focused on:

- product validation
- platform compliance
- performance and privacy evidence
- App Store and TestFlight readiness

It does not expand into:

- on-call design
- incident runbooks
- service ownership matrices
- SRE process work

## Documentation Inputs That Inform This Design

Apple guidance:

- Xcode 26.5 system requirements and release notes
- tvOS 26 release notes
- Human Interface Guidelines for tvOS
- focus and selection guidance
- AVKit and AVPlayerViewController guidance
- privacy manifest documentation
- App Review Guidelines
- TestFlight documentation
- TV Services / Top Shelf documentation

Plex guidance:

- Plex Media Server API documentation
- Plex account/resource APIs
- public product documentation for discover and universal watchlist behavior where API docs are incomplete

## Success Condition For The Roadmap Rewrite

The roadmap rewrite is successful when:

- the program is organized around epics and gates instead of late quality phases
- Epic 0 becomes a true cross-cutting stream
- Epic 5 is constrained to ship validation rather than invented operations work
- the repo’s actual risks are reflected in epic order and wave sequencing
- later implementation planning can decompose the work into reviewable, non-regressive slices

