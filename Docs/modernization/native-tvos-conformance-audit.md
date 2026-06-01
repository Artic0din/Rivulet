# Native tvOS Conformance Audit (Full Application)

Date: 2026-06-02 (v2 — full file-level sweep)
Status: audit only — no code, no project-setting, no playback change.
Method: 8 parallel read-only domain sweeps across all 271 Swift files (~80k LOC) +
spot-verification of the highest-severity findings. Supersedes the v1 surface pass.
Rule: **native by default; keep custom only where native cannot achieve
equal-or-better capability**; never remove a feature to become native.

Classifications: **A** native/conforming · **B** should migrate to native · **C**
custom justified · **D** custom temporary/dead · **E** non-conforming/defect.

Confidence: findings marked **[verified]** were read directly this pass; others
are scanner-reported with file:line and should be code-confirmed before any fix.

## Apple documentation consulted (docs MCP)

Observation macro migration (verified); AVKit content-proposals / customizing tvOS
playback / navigation-markers / `AVPlayerViewControllerDelegate` (verified, prior
audit); `AVMetadataIdentifier`, `TVTopShelfContentProvider`, App Privacy
(required-reason APIs), ATS / `NSAllowsLocalNetworking`, SwiftData
`VersionedSchema`/`SchemaMigrationPlan`, Swift Observation/concurrency — established
public API. SwiftUI/tvOS focus pages are JS-SPA (not machine-rendered; applied from
known API).

---

## Executive assessment

Structurally Rivulet is **largely native**: SwiftUI `App`/`WindowGroup`,
`TabView(.sidebarAdaptable)` + `NavigationStack` + `navigationDestination`,
SwiftData, native `AVPlayerViewController` (with native `externalMetadata` +
`navigationMarkerGroups`), native `TVTopShelfContentProvider`, native `AppIntents`,
`OSSignposter`, `Vision`, `Keychain`, and a deep, correct image cache. The custom
code in the FFmpeg/RPlayer pipeline and image cache is genuinely justified — native
cannot match it.

But a real file-level sweep (which the v1 pass did not do) surfaces material
**defects and conformance gaps** that the structural view hid:

- **Security/TLS:** `PlexThumbnailService` accepts **any** TLS certificate from any
  host [verified]; the scoped Plex trust bypass also covers `.plex.direct` (valid CA
  certs) and any port-32400 host, broader than needed. ATS uses blanket
  `NSAllowsArbitraryLoads`.
- **A reliability defect [verified]:** transcode decision/stop requests use
  `URLSession.shared`, bypassing the self-signed-cert `URLSession` delegate — they
  silently fail on self-signed/`.plex.direct`/IP servers.
- **SwiftData has no migration plan [verified]** + `fatalError` on container-init
  failure — a model change ships a store-breaking update; and `WatchProgress` +
  the entire IPTV `@Model` graph are registered-but-dead (persistence actually goes
  through `UserDefaults`).
- **Swift 6 not enforced:** `SWIFT_VERSION = 5.0`, no `SWIFT_STRICT_CONCURRENCY`, so
  the `@unchecked Sendable` + cross-actor singletons (notably `PlexNetworkManager`)
  are unchecked data-race risk.
- **State layer:** ~19 `ObservableObject` + ~50 `@StateObject`/`@ObservedObject`
  sites vs 4 `@Observable` — the platform-preferred pattern at tvOS 26.
- **Accessibility:** Settings and player controls have **zero** VoiceOver
  annotations; grid poster cards (`MediaPosterCard`/`DiscoverTile`) and EPG cells
  lack labels; Increase-Contrast/Reduce-Motion handled only in a few views.
- **Native deviations:** custom post-play overlay over the native player (→
  `AVContentProposal`, E4-PR9); two fragile focus workarounds in `TVSidebarView`
  (a 1.5s polling watchdog + a runtime **method swizzle** of `shouldUpdateFocus` on
  an internal `UICollectionView` class).
- **Dead code / DRY:** several unused files; preview/player-launch boilerplate
  triplicated across Home/Library/Discover.

Correction to a scanner finding: the "duplicate `RivuletPlayer`/FFmpeg class"
flags are **not** defects — they are a clean `#if !RIVULET_FFMPEG … #else … #endif`
compile split [verified]. Classified **A**.

None of these block Epic 4's remaining **pure-policy** slices (E4-PR5). Several are
**App-Store / pre-ship (Epic 5) blockers** and a few are functional defects worth
scheduling regardless of Epic.

---

## Mandatory matrix (representative — full findings below)

| Component | Current | Native alternative | Native equal/better? | Class | Recommendation |
| --- | --- | --- | --- | --- | --- |
| App / scene / navigation | SwiftUI App + NavigationSplitView/TabView(.sidebarAdaptable)/NavigationStack | same | n/a | **A** | Keep |
| State layer | ObservableObject + @StateObject (×~50 sites) | `@Observable` + `@State`/`@Bindable`/`@Environment` | Yes (perf, tvOS 17+) | **B** | Incremental migrate |
| Swift language mode | `SWIFT_VERSION 5.0`, no strict concurrency | Swift 6 + complete checking | Yes (goal) | **E** | After concurrency cleanup |
| `PlexNetworkManager`/providers `@unchecked Sendable` | unguarded mutable singletons | `actor`/`@MainActor` | Yes | **B/E** | Isolate; data-race risk |
| FFmpeg/CoreMedia threading (`@unchecked`, locks, Task.detached) | C-callback real-time | actors | No (C interop/real-time) | **C** | Keep |
| RPlayer / FFmpeg / Dovi / remux / FFmpeg subs | custom pipeline | AVKit | No (DV P7/P8.6, lossless, 4K-HTTP, ASS/PGS) | **C** | Keep (capability fallback) |
| Native video player | barebones `AVPlayerViewController` | same | n/a | **A** | Keep; add delegate (E4-PR9) |
| Post-play overlay over native player | custom SwiftUI | `AVContentProposal` (AVKit path) | Yes on AVKit path | **E** | E4-PR9 native proposal + shared decision layer |
| Chapters / external metadata | `navigationMarkerGroups` / `externalMetadata` | same | n/a | **A** | Keep (device-verify) |
| Image cache | `CachedAsyncImage`/`ImageCacheManager` | `AsyncImage` | No (no disk/TTL/sizing) | **C** | Keep |
| Focus restoration | `FocusMemory`/`FocusRestorationPolicy` | `@FocusState`/`.focusSection` | No (no persistence across reloads) | **C** | Keep |
| Sidebar focus watchdog + swizzle | polling + `class_replaceMethod` | native focus engine | No today (workaround) | **E/D** | Root-cause; retire |
| TLS trust (`PlexThumbnailService`) | accept any cert, any host | scoped trust / OS eval | Yes | **E** | Fix (security) |
| TLS trust (Plex scoped) | IP + `.plex.direct` + port-32400 | IP-only bypass; OS eval for `.plex.direct` | Yes (narrower) | **E** | Tighten |
| Transcode decision/stop requests | `URLSession.shared` | `self.session` (cert delegate) | Yes | **E** | Fix (reliability) |
| ATS | `NSAllowsArbitraryLoads` | `NSAllowsLocalNetworking` + exceptions | Mostly | **E** | Tighten (App Store) |
| SwiftData store | bare `Schema` + `fatalError`; dead models | `VersionedSchema` + `SchemaMigrationPlan` | Yes | **E** | Add migration; remove/activate dead models |
| Settings UI | custom rows (Button-as-Toggle) | native `List`/`Toggle`/`Picker` | Partly (a11y better) | **B/E** | Add a11y or native controls |
| Top Shelf | `TVTopShelfContentProvider` | same | n/a | **A** | Fix displayAction + server param (D) |
| Adaptive tint / badges / status labels / design tokens / GlassRowStyle | custom SwiftUI | n/a | n/a | **C** | Keep |
| AppIntents / Keychain / Vision / OSSignposter | native frameworks | same | n/a | **A** | Keep |

---

## Findings (consolidated, by domain)

### Security / privacy / config

- **NTC-SEC-001 [verified] — `PlexThumbnailService.TrustingSessionDelegate` accepts ANY cert from ANY host.** `Services/Plex/PlexThumbnailService.swift:170`. **E, High.** App-Store rejection risk + MITM on BIF thumbnail fetches. Native: reuse the scoped Plex trust logic (IP-only) or OS evaluation. Epic-4: no; **Epic-5/App-Store blocker.**
- **NTC-SEC-002 [verified] — Scoped Plex trust bypass too broad.** `PlexNetworkManager.swift:~2649`, `PlexAuthManager.swift:~924`, `ImageCacheManager.swift:~595`: bypass for `.plex.direct` (valid Let's-Encrypt CA — should use OS eval) and **any** port-32400 host. **E, High.** Restrict unconditional trust to IP literals; OS-evaluate `.plex.direct`. Also DRY: 3–4 identical delegates → one shared `PlexSSLTrust`.
- **NTC-SEC-003 [verified] — Transcode decision/stop use `URLSession.shared`.** `PlexNetworkManager.startTranscodeDecision:~1640`, `stopTranscodeSession:~1703` bypass `self.session`'s cert delegate → silently fail on self-signed/`.plex.direct`/IP servers (errors swallowed). **E, High, functional defect.** Fix: use `self.session`. (Confirmed: both call `URLSession.shared.data(for:)`.)
- **NTC-SEC-004 [verified] — ATS `NSAllowsArbitraryLoads = true`.** `Info.plist:21`. **E, Medium, App-Store friction.** `NSAllowsLocalNetworking` covers LAN http; `.plex.direct` is https; m3u4u.com already has an exception domain → blanket arbitrary loads is removable. (`DEBT-E0-001`.)
- **NTC-SEC-005 — Sentry exposure surface.** `tracesSampleRate = 1.0` + `enableSwizzling = true` (`RivuletApp.swift:59/65`) may capture URLSession spans (URLs/query) outside the `beforeSend` sanitiser; scope-closure `setExtra(url.path…)` bypasses `sanitizeSentryEvent` (`PlexLiveTVModels.swift:320/331/421`, `MultiStreamViewModel:296`, `HLSSegmentFetcher:189`). **B, Medium-High.** Lower sample rate; route scope extras through redactor; confirm span scrubbing for the SDK version.
- **NTC-SEC-006 — Entitlements over-broad.** `remote-notification` background mode + `aps-environment` with no push code; duplicate `aps-environment` keys. **D, Low.** Remove unused.
- **NTC-SEC-007 — `TMDBConfig.proxyBaseURL` hardcoded personal Worker** (`baingurley.workers.dev`). **G/Medium** for public release (no override/fallback). Secrets otherwise clean (Secrets.swift gitignored). PrivacyInfo present; review `ProductInteraction`/ratingKey disclosure (Low).

### Concurrency / Swift 6

- **NTC-CON-001 [verified] — `SWIFT_VERSION = 5.0`, no `SWIFT_STRICT_CONCURRENCY`.** All targets. **E, High.** Concurrency guarantees are not compiler-enforced. Target Swift 6 mode after cleanup; do not flip until clean (project-setting → explicit go).
- **NTC-CON-002 — `PlexNetworkManager: @unchecked Sendable` singleton, unguarded mutable state, called from many actors + `Task.detached`.** **E/B, High.** Make `@MainActor` or `actor`. Primary Swift-6 data-race blocker. Same pattern (lower risk): `TMDBClient`, `PlexProvider`, `PlexMusicProvider`, `HomePerformanceTracer` (NSLock), `FileWatchlistCache`.
- **NTC-CON-003 — GCD/locks vs structured concurrency:** 53 `DispatchQueue`, 31 `Task.detached`, ~30 lock/`@unchecked`. Non-FFmpeg sites → actors/structured concurrency (**B**); `.receive(on: DispatchQueue.main)` inside `@MainActor` is redundant (×10). FFmpeg/CoreMedia threading (demux read loop, AVIO callbacks, `SampleBufferRenderer` `nonisolated(unsafe)`, remux interrupt ptr, LocalRemuxServer NWConnection locks) → **C, keep**.
- **NTC-CON-004 — `RivuletPlayer`/FFmpeg "duplicate classes" are `#if !RIVULET_FFMPEG` splits [verified].** **A — not a defect.** (Corrects scanner E1/E2.)
- Minor: `WatchlistHubRow:89` `await MainActor.run { Task { … } }` double-hop; `NowPlayingService` fire-and-forget remote-command Tasks need `[weak]` audit; `UPVM:1440` NSLock inside `withCheckedContinuation` is redundant.

### Persistence / models

- **NTC-DAT-001 [verified] — No SwiftData migration plan + `fatalError` on init.** `RivuletApp.swift:127/143/145`. **E, Critical (data integrity).** Any `@Model` change destroys/drops the store on upgrade. Add `VersionedSchema` + `SchemaMigrationPlan`; replace `fatalError` with graceful reset. **Gates any model change.**
- **NTC-DAT-002 — Dead persistence graph.** `WatchProgress` + IPTV `@Model`s (`Channel`/`EPGProgram`/`FavoriteChannel`/`IPTVSource`) are schema-registered but never `@Query`-ed/written; Live TV persists via `UserDefaults` JSON (incl. `apiToken` — should be Keychain). **E/B, Medium.** Activate or remove (with migration); move tokens to Keychain.
- **NTC-DAT-003 — Unstable `Identifiable.id` fallbacks.** `PlexTag`/`PlexExtra`/`PlexHub` use `UUID().uuidString` fallback (new identity every access → ForEach diffing bugs); `PlexRole`/`PlexCrewMember` composite ids collide on "unknown". **C, Medium.** Stable hashes.
- **NTC-DAT-004 — `try?`-everywhere decoders** in `TMDBListItem`/`TMDBItemDetail` silently swallow decode failures (cast/genres default to `[]`). **C, Low.** Per-field tolerance OK; lose-vs-empty ambiguity noted. `EPGProgram.timeRangeFormatted` allocates a `DateFormatter` per call (**A, perf**). `useApplePlayer` read from `UserDefaults.standard` at 5 sites (not reactive) → single `@AppStorage`.

### Playback

- **NTC-PLY-001 — Post-play overlay over native player → native `AVContentProposal`.** **E** → E4-PR9 (already tracked `DEBT-E4-AVKIT-001`).
- **NTC-PLY-002 — RPlayer / FFmpeg / Dovi / FFmpegAudioDecoder / URLSessionAVIOSource / FFmpeg subtitles / LocalRemux / DisplayCriteriaManager / NowPlayingService.** **C, custom justified** — native cannot match DV P7/P8.6, TrueHD/DTS-HD/DTS:X/PCM/FLAC, 4K-over-HTTP, ASS/PGS, or `AVDisplayManager`/Now-Playing driving for the sample-buffer path. Keep.
- **NTC-PLY-003 — Dead player code [scanner].** `PlayerProgressBar.swift`, `TrackSelectionSheet.swift`, `VideoInfoOverlay.swift` have no live call sites (transport/track/info are inline in `PlayerControlsOverlay`). **D.** Confirm then remove.
- **NTC-PLY-004 — AVPlayer-via-`AVPlayerLayerView` mixed path** (custom controls + manual Now Playing on AVPlayer content when not `useApplePlayer`) is architecturally inconsistent vs the clean `NativePlayerViewController` path. **B/E, Medium.** Clarify/route through native VC where possible.
- **NTC-PLY-005 — Defects [scanner]:** `UPVM:1929` `segments.first!` force-unwrap; `UPVM:1908` `as! AVMetadataItem`; `PlayerControlsOverlay:559` deprecated `UIScreen.main`; ~14 `DispatchQueue.main.asyncAfter` focus-timing hacks; `print()` of internal state (route through `playerDebugLog`); `NowPlayingService:544` inline token-in-URL (cache key — keep out of logs). **C/E, Low-Medium.**

### Navigation / focus

- **NTC-FOC-001 [scanner] — `TVSidebarView.focusRecoveryWatchdog`** polls `windowScene.focusSystem.focusedItem` every 1.5s and `resetFocus` if nil. **E, High.** Fragile, masks an un-root-caused focus loss; non-exhaustive overlay guard. Root-cause + targeted reset.
- **NTC-FOC-002 [scanner] — `installSidebarFocusGuard`/`overrideSidebarFocusBehavior`** runtime-swizzles `shouldUpdateFocus(in:)` on an internal `UICollectionView` subclass found via a width<500/x=0 heuristic. **E, High.** Undefined behaviour across SDKs; applies globally to that class; breaks on sidebar restructure. Replace with `.focusSection()` containment / native API.
- **NTC-FOC-003 — `FocusMemory`/`FocusRestorationPolicy` (C, justified)** and `NestedNavigationState` (C, justified — no native nested-push signal). `FocusContainedView`/`LiveTVPressCatcher`/`PreviewContainerViewController` UIKit interop (C, justified). DRY: `FocusContainedView` duplicated in Settings + Music (Music uses the weaker `shouldUpdateFocus` approach the Settings comment says is insufficient) — **E, consolidate.**
- **NTC-FOC-004 — Player/preview launch + `presentPreview` boilerplate triplicated** across Home/Library/Discover via `UIApplication.shared.connectedScenes` VC-walk (8 sites). **C/E (DRY), Medium.** One `WindowPresenter`.

### Content / media UI

- **NTC-UI-001 [scanner] — Missing accessibility on primary grid items.** `MediaPosterCard`, `DiscoverTile`, EPG `ProgramCell` have no `.accessibilityLabel` (contrast: `ContinueWatchingCard`/`LandscapeContentCard` do). **E, High (a11y).**
- **NTC-UI-002 — `UIScreen.main.bounds` for hero height** (`PlexHomeView:693`, `PlexLibraryView:473`, `DiscoverView:39`) — deprecated; `GeometryReader` already present. **A, Low.**
- **NTC-UI-003 — Manual focus rings duplicating native** (`SeasonPillButton`, `EpisodeCard` thumbnail border) → `.buttonStyle(.card)`/`.hoverEffect`. **B, Low.** Custom EPG grid / Preview carousel / Hero two-layer / `AppStoreActionButtonStyle` / dual-focus EpisodeCard = **D/C justified** (no native equivalent).
- **NTC-UI-004 — `MediaDetailView.swift` 3825 lines** (type-checker budget comments) → extract sub-views. **E, High (maintainability).** Dead/divergent: `ContentRow`, `searchField`, `ParallaxPosterImage/LayerStack`, `computeProcessedHubs` divergence Home vs Library. `DiscoverView` uses `fullScreenCover` vs NavigationStack elsewhere (inconsistent).

### Services (non-playback)

- **NTC-SVC-001 — `PlexNetworkManager` 2719-line God object** (auth/discovery/browse/streaming/LiveTV/progress/XML). **E, architecture.** Extract domain clients (pattern already started: `PlexWatchlistAPI`/`PlexTimelineReporter`).
- **NTC-SVC-002 — Regex-per-call hotspots:** `M3UParser.extractAttribute` (~3000 compiles/500-ch playlist), `PlexNetworkManager.parseHomeUsersXML`, `PlexAuthManager.extractPlexDirectHash` (locale-fragile). **A/B, perf.** Static `Regex`/`XMLParser`.
- **NTC-SVC-003 [scanner] — `XMLTVParser` drops timezone offsets** (hardcodes UTC for `yyyyMMddHHmmss ±HHMM`). **E, Medium (EPG times wrong in non-UTC feeds).**
- **NTC-SVC-004 — `CacheManager` `NSCache` no `totalCostLimit`** (count-only, unbounded bytes → jetsam risk). **C, Medium.** `PersonalizedRecommendationService` serial per-candidate TMDB fetch → `withTaskGroup` (**C, Medium**). `ImageCacheManager`/`CachedAsyncImage`/Keychain/Vision/AppIntents/OSSignposter = **A/C justified, clean.**

### Settings / Top Shelf / a11y

- **NTC-SET-001 [scanner] — Settings: zero VoiceOver annotations.** `SettingsToggleRow` is a Button-as-Toggle with no `.isToggle`/`.accessibilityValue`; pickers no value; chevrons not hidden. **E, High (a11y).** Add traits or adopt native `Toggle`/`Picker`.
- **NTC-SET-002 [scanner] — Top Shelf:** `displayAction = playAction` (highlight may trigger playback) and the `&server=` param is ignored by `DeepLinkHandler` (multi-server → wrong/failed item). **D/E, Medium** (the latter is a multi-server correctness defect). Also localise `section.title`; use `subtitle`.
- **NTC-SET-003 — Increase Contrast / Reduce Motion only in a few views** (`AdaptiveTintLayer` exemplary). `GlassRowBackground` 0.08 resting fill may fail Increase Contrast. **E, Medium (a11y systemic).** `PlaybackInputCoordinator`/design-tokens/badges = **A/C justified.**

---

## Remediation roadmap (no parity reduction)

**Priority 1 — defects / security / App-Store (schedule regardless of Epic):**
1. NTC-SEC-001 unconditional TLS trust (`PlexThumbnailService`) — **App-Store/security.**
2. NTC-SEC-002 tighten Plex trust scope (IP-only; OS-eval `.plex.direct`) + DRY one delegate.
3. NTC-SEC-003 transcode requests use `self.session` — **functional defect.**
4. NTC-DAT-001 SwiftData `VersionedSchema`+`SchemaMigrationPlan` + graceful init — **data integrity; gates model changes.**
5. NTC-SEC-004 ATS scoping; NTC-SEC-005 Sentry sample-rate/span scrubbing.

**Priority 2 — native migrations / defects, no feature loss:**
6. NTC-FOC-001/002 root-cause the sidebar focus loss; retire the watchdog + swizzle.
7. NTC-PLY-001 / E4-PR9 native post-play `AVContentProposal`.
8. NTC-CON-002 isolate `PlexNetworkManager` + providers (actor/@MainActor); NTC-CON-003 non-FFmpeg GCD→structured; then NTC-CON-001 Swift 6 mode.
9. NTC-UI-001 / NTC-SET-001 / NTC-SET-003 accessibility (grid cards, EPG cells, settings, contrast/motion).
10. NTC-SVC-003 XMLTV timezone; NTC-SVC-004 cache cost limit + recommendation task-group; NTC-DAT-002 dead persistence graph (activate/remove + Keychain tokens).

**Priority 3 — polish / debt:**
11. NTC-CON / NTC-DAT-003 `@Observable` migration + stable ids.
12. NTC-UI-004 / NTC-SVC-001 split God-objects; NTC-FOC-004 shared `WindowPresenter`; NTC-PLY-003 remove dead player files (after confirmation).
13. Entitlement trim, hardcoded proxy override, localisation, metadata enrichment.

**Custom kept (native cannot match — no change):** RPlayer/FFmpeg/Dovi/remux/FFmpeg-subs, image disk cache, FocusMemory policy, adaptive tint/badges/status labels/design tokens, EPG grid, preview carousel, hero two-layer, AppIntents/Keychain/Vision/OSSignposter, IP-scoped self-signed trust (the legitimate Plex case).

---

## Epic 4 blockers

**No finding blocks Epic 4's remaining pure-policy slices (E4-PR5).** NTC-PLY-001 is
the E4-PR9 slice. The AVKit default flip (E4-PR6) stays corpus/device-gated.
NTC-SEC-003 (transcode `URLSession.shared`) is a playback **reliability** defect on
self-signed servers worth fixing before the flip's device validation. The
security/ATS/SwiftData/a11y items are **Epic-5 pre-ship / App-Store** blockers, not
Epic-4 blockers.

*Method note: aggregated from 8 read-only domain sweeps; the four highest-severity
new claims were code-verified this pass. Items marked [scanner] carry file:line and
should be confirmed at fix time (root-cause-first). No functionality is recommended
for removal to become "more native"; every retained-custom item has a stated
capability reason. No code, settings, or playback changed.*
