# Native tvOS Conformance Audit (Full Application)

Date: 2026-06-02
Status: audit only — no code, no project-setting, no playback change.
Rule applied: **native by default; custom only where native cannot achieve
equal-or-better capability** (burden of proof is on keeping custom, not on native).

Classifications: **A** native/conforming · **B** should migrate to native · **C**
custom justified · **D** custom temporary · **E** non-conforming/defect.

## Apple documentation consulted (via docs MCP)

- Migrating from the ObservableObject protocol to the Observable macro (Observation; tvOS 17+) — verified.
- Customizing the tvOS Playback Experience; Presenting Content Proposals in tvOS; Presenting Navigation Markers; AVPlayerViewControllerDelegate — verified in the prior AVKit audit (`apple-avkit-playback-reference-audit.md`).
- AVKit metadata identifiers / AVPlayerViewController — from established public API (already used in code).
- SwiftUI focus, Top Shelf (`TVTopShelfContentProvider`), App privacy, Swift concurrency — established public guidance; SwiftUI/tvOS focus pages are JS-SPA (not machine-rendered this pass; applied from known API).

---

## Executive assessment

Rivulet is **substantially native already** for structure: SwiftUI `App` +
`WindowGroup`, `NavigationSplitView` + `TabView(.sidebarAdaptable)` +
`NavigationStack`, **SwiftData** persistence, native `AVPlayerViewController`
(with native `externalMetadata` + `navigationMarkerGroups`), native Top Shelf,
and a present `PrivacyInfo.xcprivacy`. The custom code that exists is mostly in
two legitimately-custom domains — the RPlayer FFmpeg pipeline (capability native
AVKit lacks) and the image disk cache (native `AsyncImage` lacks persistence).

The real native-conformance gaps are **not** UI: they are (1) **state layer** —
20 `ObservableObject` types + 23 `@StateObject` vs only 4 `@Observable` (Observation
is available at tvOS 26 and is the platform-preferred pattern); (2) **concurrency**
— `SWIFT_VERSION = 5.0` (not Swift 6 language mode) with 53 `DispatchQueue`, 31
`Task.detached`, and ~30 lock/`@unchecked` sites; (3) **ATS** — `NSAllowsArbitraryLoads
= true` (App Store + security risk). One playback deviation: the custom post-play
overlay drawn over the native player (→ native `AVContentProposal`, E4-PR9).

None of these block Epic 4's pure-policy slices; the ATS + Swift-6 items are
pre-ship (Epic 5) and the state migration is independent.

---

## Mandatory matrix

| Component | Current Implementation | Native Alternative | Native Equal/Better? | Classification | Recommendation |
| --- | --- | --- | --- | --- | --- |
| App lifecycle / scene | SwiftUI `App` + `WindowGroup` | same | n/a | **A** | Keep |
| Navigation (sidebar/tabs) | `NavigationSplitView` + `TabView(.sidebarAdaptable)` + `NavigationStack` | same | n/a | **A** | Keep; verify no leftover custom nav |
| Persistence | SwiftData `@Model` (Channel/PlexServer/WatchProgress/…) | SwiftData | n/a | **A** | Keep |
| State layer | 20× `ObservableObject` + 23× `@StateObject`; 4× `@Observable` | `@Observable` macro + `@State`/`@Environment` | **Yes** (perf: updates only on read props; tvOS 17+/26) | **B** | Migrate incrementally to `@Observable` |
| Image loading/cache | custom `CachedAsyncImage` + `ImageCacheManager` (disk TTL/5GB, Plex transcode sizing, token) | `AsyncImage` | **No** (no persistent disk cache / TTL / sizing) | **C** | Keep; document gap |
| Focus restoration | `FocusMemory` + `FocusRestorationPolicy` | `@FocusState` + `.focusSection` + `prefersDefaultFocus` | **No** (native doesn't persist section focus across data reloads) | **C** | Keep (tested policy) |
| Focus watchdog / `focusSystem` recovery (TVSidebarView) | custom recovery + UIKit focus poke | native focus engine | **No today** (works around a focus-loss edge) | **D** | Keep; re-test each tvOS release, remove when native stable |
| Native video player | `AVPlayerViewController` (`NativePlayerViewController`) | same | n/a | **A** | Keep; add delegate for post-play (E4-PR9) |
| RPlayer (FFmpeg + AVSampleBuffer) | custom pipeline | AVKit/VideoToolbox | **No** (DV P7/P8.6 RPU rewrite, TrueHD/DTS-HD/DTS:X/PCM/FLAC decode, 4K-over-HTTP via URLSessionAVIO) | **C** | Keep as capability fallback |
| Custom player controls (`PlayerControlsOverlay`/`PlayerProgressBar`/`VideoInfoOverlay`/`TrackSelectionSheet`) | custom SwiftUI | AVKit transport | **No for RPlayer** (RPlayer isn't `AVPlayerViewController`); **N/A for AVKit path (native already used)** | **C** | Keep for RPlayer only; ensure none layer over the native player |
| Chapters | `navigationMarkerGroups` (`includeChapters=1`) | same | n/a | **A** | Keep (device-verify) |
| Player external metadata | `item.externalMetadata` (public identifiers, token-safe) | same | n/a | **A** | Keep; minor enrichment backlog |
| Post-play / next-up | custom SwiftUI overlay over native player | `AVContentProposal` + `AVContentProposalViewController` + delegate (AVKit path) | **Yes on AVKit path** (system-shrunk video, native focus) | **E** | E4-PR9: native proposal on AVKit path + shared decision layer; overlay → RPlayer-only |
| Top Shelf | `TVTopShelfContentProvider` (local-file handoff) | same | n/a | **A** | Keep |
| Adaptive tint / badges / status labels | custom SwiftUI (pure policies) | n/a (no native equivalent) | n/a | **C** | Keep (Plex/TMDb-derived, a11y-gated) |
| Concurrency (DispatchQueue×53 / Task.detached×31 / locks×30) | mixed GCD + structured | actors + structured concurrency | **Partly** (non-FFmpeg sites) | **B/C** | Migrate non-FFmpeg GCD/locks to actors; FFmpeg threading stays **C** |
| Swift language mode | `SWIFT_VERSION = 5.0` (+ approachable concurrency, `@MainActor` default) | Swift 6 mode | **Yes (goal)** | **E** | Reach Swift 6 mode after concurrency cleanup (`DEBT-E0`-class) |
| ATS | `NSAllowsArbitraryLoads = true` (+ some exception domains) | scoped `NSExceptionDomains` only | **Partly** (Plex LAN http on dynamic hosts complicates full scoping) | **E** | Tighten toward scoped exceptions; document residual LAN-http constraint (`DEBT-E0-001`) |
| Privacy manifest | `PrivacyInfo.xcprivacy` present | same | n/a | **A** | Keep; keep matrix current |
| Token / URL safety | redacted (E4-PR1) | n/a | n/a | **A** | Keep |

---

## Findings

Each: ID · severity · category · files · current · native · capability comparison
· classification · recommendation · owner · Epic-4-blocker?

### NTC-001 — ObservableObject → @Observable (state layer)
- **Severity:** Medium · **Category:** State/SwiftUI · **Files:** ~20 view models (`UniversalPlayerViewModel`, home/discover/livetv VMs, etc.)
- **Current:** `ObservableObject` + `@Published` + `@StateObject`/`@ObservedObject`. **Native:** `@Observable` macro + `@State`/`@Environment`/`@Bindable`.
- **Capability:** native is **equal-or-better** — view updates only when read properties change (perf), tracks optionals/collections, fewer wrappers (Apple Observation doc, tvOS 17+; deployment is 26). No capability lost.
- **Classification:** **B (should migrate)** · **Recommendation:** incremental migration (Apple-supported; `@StateObject` still accepts `@Observable` during transition). Start with leaf VMs; defer `UniversalPlayerViewModel` until its concurrency is settled. · **Owner:** modernization backlog · **Epic-4 blocker:** No.

### NTC-002 — Swift 6 language mode not enabled
- **Severity:** High · **Category:** Concurrency/build · **Files:** `Rivulet.xcodeproj/project.pbxproj` (`SWIFT_VERSION = 5.0`)
- **Current:** Swift 5 mode with `SWIFT_APPROACHABLE_CONCURRENCY` + `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. **Native:** Swift 6 language mode (full strict concurrency).
- **Capability:** Swift 6 is the goal (data-race safety). Blocked by the GCD/lock/`Task.detached` surface (NTC-003). No feature lost by migrating; it's gated work.
- **Classification:** **E (non-conforming vs target)** · **Recommendation:** sequence behind NTC-003; do **not** flip `SWIFT_VERSION` until strict-concurrency-clean (this is a project-setting change — out of current scope). · **Owner:** Epic 5 / dedicated slice · **Epic-4 blocker:** No (but Epic 5 pre-ship).

### NTC-003 — GCD / Task.detached / manual locks vs structured concurrency
- **Severity:** Medium · **Category:** Concurrency · **Files:** 53 `DispatchQueue`, 31 `Task.detached`, ~30 lock/`@unchecked` sites across services/playback.
- **Current:** mixed GCD + ad-hoc locks. **Native:** `actor` isolation + structured `async`/`await` + `AsyncStream`.
- **Capability:** for non-FFmpeg sites, actors/structured concurrency are equal-or-better (race safety, cancellation). **FFmpeg/CoreMedia threading** (read loop, AVIO callbacks, renderer) is **C — custom justified** (C-callback threading, real-time constraints native Swift concurrency doesn't model well).
- **Classification:** **B** (non-FFmpeg) / **C** (FFmpeg) · **Recommendation:** migrate non-FFmpeg GCD/locks to actors incrementally; keep + document FFmpeg threading. · **Owner:** modernization backlog (prereq for NTC-002) · **Epic-4 blocker:** No.

### NTC-004 — ATS arbitrary loads
- **Severity:** High · **Category:** Security/privacy/App Store · **Files:** `Rivulet/Info.plist` (`NSAllowsArbitraryLoads = true`)
- **Current:** blanket arbitrary loads (+ some exception domains). **Native/compliant:** scoped `NSExceptionDomains` with `NSAllowsLocalNetworking` for LAN.
- **Capability:** Plex servers on dynamic LAN IPs/hostnames over http complicate full scoping, but `NSAllowsLocalNetworking` + scoped exceptions cover the legitimate case without blanket arbitrary loads — equal capability, lower risk.
- **Classification:** **E (defect)** · **Recommendation:** tighten to `NSAllowsLocalNetworking` + scoped exceptions; document any residual. Existing `DEBT-E0-001`/`KF-E0-001`. · **Owner:** Epic 1/5 security · **Epic-4 blocker:** No (App Store pre-ship).

### NTC-005 — Post-play overlay over native player
- **Severity:** Medium · **Category:** Playback/HIG · **Files:** `Views/Player/PostVideo/*`, `UniversalPlayerView`
- **Current:** custom SwiftUI post-play overlay drawn over `AVPlayerViewController`. **Native:** `AVContentProposal` + `AVContentProposalViewController` + `AVPlayerViewControllerDelegate` (AVKit path).
- **Capability:** native is **better on the AVKit (default) path** (system-shrunk video, native focus/Siri-Remote/auto-accept). RPlayer path can't use it.
- **Classification:** **E** · **Recommendation:** **E4-PR9** — shared Plex post-play decision layer → native proposal on AVKit path + overlay reused only for RPlayer. (`DEBT-E4-AVKIT-001`.) · **Owner:** Epic 4 · **Epic-4 blocker:** it IS an Epic 4 slice (not a blocker of others).

### NTC-006 — RPlayer / FFmpeg pipeline (custom justified)
- **Severity:** Low (informational) · **Category:** Playback · **Files:** `Services/Plex/Playback/**`
- **Current:** FFmpeg demux + VideoToolbox + AVSampleBuffer render. **Native:** AVKit/AVPlayer.
- **Capability:** native **cannot** match — DV P7 MEL/P8.6 RPU rewrite, TrueHD/DTS-HD/DTS:X/PCM/FLAC client decode, 4K HEVC/DV over plain HTTP (`URLSessionAVIOSource`). Removing it = feature loss.
- **Classification:** **C (custom justified)** · **Recommendation:** keep as the capability fallback; AVKit-first routes everything else to native (E4-PR3/PR6). · **Epic-4 blocker:** No.

### NTC-007 — CachedAsyncImage / ImageCacheManager (custom justified)
- **Severity:** Low · **Category:** Images · **Files:** `Views/Components/CachedAsyncImage.swift`, `Services/Cache/ImageCacheManager.swift`
- **Current:** custom disk cache (2-week TTL, 5GB), Plex `/photo/:/transcode` sizing, actor-isolated. **Native:** `AsyncImage` (memory only, no TTL/disk/sizing).
- **Capability:** native **cannot** match (no persistent cache, no sizing control). Removing it regresses scroll perf + bandwidth.
- **Classification:** **C** · **Recommendation:** keep; it's already actor-backed (native concurrency). · **Epic-4 blocker:** No.

### NTC-008 — FocusMemory / FocusRestorationPolicy (custom justified) + watchdog (temporary)
- **Severity:** Low · **Category:** Focus · **Files:** `Services/Focus/FocusMemory.swift`, `FocusRestorationPolicy`, `Views/TVNavigation/TVSidebarView.swift`
- **Current:** custom section-focus persistence across data reloads + a `focusSystem` recovery watchdog. **Native:** `@FocusState`/`.focusSection`/`prefersDefaultFocus`.
- **Capability:** native primitives are used everywhere they suffice; the custom layer covers what native does **not** — restoring focus to a remembered item after a list refresh, and recovering from a focus-loss edge. The recovery watchdog is a workaround.
- **Classification:** `FocusMemory`/policy = **C**; recovery watchdog = **D (temporary)** · **Recommendation:** keep the tested policy; re-test the watchdog each tvOS release and retire if native stabilises. · **Epic-4 blocker:** No.

### NTC-009 — Custom player controls scope check
- **Severity:** Low · **Category:** Playback/HIG · **Files:** `PlayerControlsOverlay`/`PlayerProgressBar`/`VideoInfoOverlay`/`TrackSelectionSheet`
- **Current:** custom controls. **Native:** AVKit transport (already used on the AVPlayer path).
- **Capability:** native covers the `AVPlayerViewController` path (already native); custom controls are required for the **RPlayer** path (not an AVPlayerViewController).
- **Classification:** **C (RPlayer-only)** · **Recommendation:** keep for RPlayer; **verify** none of these are layered over the native player (only NTC-005's post-play overlay is — fix there). · **Epic-4 blocker:** No.

### NTC-010 — Observation/`@Observable` already used (conforming)
- **Severity:** info · 4 types already use `@Observable` (the recent policy/tint/status work). **A.** Continue the pattern for new code; it's the migration target for NTC-001.

---

## Remediation roadmap (no parity reduction)

**Priority 1 — defects / Epic-4-relevant / risk:**
1. **NTC-005 / E4-PR9** native post-play (`AVContentProposal`) — fixes the native deviation; planned Epic 4 slice.
2. **NTC-004** ATS scoping (`NSAllowsLocalNetworking` + exceptions) — App Store/security; Epic 1/5. (Project-setting change → explicit go.)

**Priority 2 — native migrations, no feature loss:**
3. **NTC-003** non-FFmpeg GCD/locks → actors/structured concurrency (prereq for NTC-002).
4. **NTC-002** Swift 6 language mode (after NTC-003). (Project-setting → explicit go; Epic 5.)
5. **NTC-001** `ObservableObject` → `@Observable` (incremental; leaf VMs first).

**Priority 3 — polish / backlog:**
6. AVKit metadata enrichment (release date, S/E identifiers) — `DEBT-E4-AVKIT-001`.
7. Focus watchdog (NTC-008 D) re-test/retire per tvOS release.
8. On-device verification of already-native metadata/chapters/GUI (`DEBT-E0-007/008`).

Items deliberately **NOT** recommended for change (native cannot match): RPlayer/
FFmpeg (NTC-006), image disk cache (NTC-007), FocusMemory policy (NTC-008 C),
RPlayer custom controls (NTC-009), adaptive tint/badges/status labels.

---

## Epic 4 blockers

**None of these findings block Epic 4's remaining pure-policy slices (E4-PR5).**
NTC-005 *is* an Epic 4 slice (E4-PR9), not a blocker. The AVKit-first default flip
(E4-PR6) remains gated on the media corpus + physical Apple TV, unchanged by this
audit. NTC-002/004 are Epic 5 pre-ship.

*Rivulet is a distinct Plex/TMDb tvOS app — no Apple branding/private APIs/partner
claims. No functionality is recommended for removal to become "more native".*
