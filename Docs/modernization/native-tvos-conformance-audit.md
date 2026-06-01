# Native tvOS Conformance Audit (Full Application)

Date: 2026-06-02 (v3 — restructured to the required scope/finding format)
Status: audit only — no code, no project-setting, no playback change.
Method: 8 parallel read-only domain sweeps across all 271 Swift files (~80k LOC),
plus direct code-verification of the highest-severity findings (marked [verified]).
Rule: **native by default; keep custom only where native cannot achieve
equal-or-better capability.** Burden of proof is on retaining custom. Never remove
a feature to become native.

Classification key: **A** native/conforming · **B** should migrate to native · **C**
custom justified · **D** custom temporary · **E** non-conforming/defect.

---

## Scope 12 — Apple documentation consulted (via docs MCP)

| Topic | Source | Verified |
| --- | --- | --- |
| Observation (`@Observable`) migration | `swiftui/migrating-from-the-observable-object-protocol-to-the-observable-macro` | Yes |
| Content proposals | `avkit/presenting-content-proposals-in-tvos` | Yes |
| Customizing tvOS playback (externalMetadata, transportBarCustomMenuItems, customInfoViewControllers, contextualActions) | `avkit/customizing-the-tvos-playback-experience` | Yes |
| Navigation markers / chapters | `avkit/presenting-navigation-markers` | Yes |
| AVPlayerViewControllerDelegate | `avkit/avplayerviewcontrollerdelegate` | Yes |
| AVKit metadata identifiers / AVPlayerViewController | AVFoundation/AVKit public API (in use in code) | API-known |
| Top Shelf (`TVTopShelfContentProvider`) | TVServices public API | API-known |
| App privacy (required-reason APIs), ATS / `NSAllowsLocalNetworking` | Apple privacy + ATS guidance | API-known |
| SwiftData `VersionedSchema`/`SchemaMigrationPlan` | SwiftData public API | API-known |
| Swift concurrency (actors, Sendable, strict checking) | Swift/Concurrency public API | API-known |
| SwiftUI on tvOS / tvOS focus / HIG / Accessibility | SwiftUI focus + HIG | JS-SPA, not machine-rendered this pass; applied from known API |

---

## Scopes 1–11 — Audit answers

Each scope states its **Question** and the answer; detailed findings (full 11-field
format) are in **Scope 13**, referenced by ID.

### Scope 1 — Whole Application Architecture
- **app lifecycle / scene:** SwiftUI `@main App` + `WindowGroup` + `UIApplicationDelegateAdaptor` for URL/`NSUserActivity` — **A**.
- **dependency flow / state ownership:** `.shared` singletons + `@StateObject` injection; `@MainActor`-isolated stores — functional but pre-Observation.
- **environment usage:** `@Environment(\.modelContext)` captured-unused in `ContentView` (NTC-014); `NestedNavigationState` via `@Environment` — **C**.
- **ObservableObject/@Observable:** ~19 `ObservableObject` + ~50 `@StateObject`/`@ObservedObject` vs 4 `@Observable` → **NTC-001 (B)**.
- **async loading / error-loading-empty surfaces:** shared `RenderState`/`ContentStateView` (Epic 2) — **A**.
- **app-level settings:** mix of `@AppStorage` and direct `UserDefaults.standard` reads (NTC-015) — **B**.
- **persistence:** SwiftData, but **no migration plan** + dead model graph → **NTC-012 (E)**, **NTC-013 (E/B)**.
- **Question — where is Rivulet custom where SwiftUI/tvOS already has a native equivalent?** State layer (`@Observable`, NTC-001) and some settings reads (NTC-015). Architecture is otherwise native.

### Scope 2 — Navigation
- sidebar `TabView(.sidebarAdaptable)`, per-tab `NavigationStack` + `navigationDestination(item:)`, `.onExitCommand`, `SidebarNavigationPolicy` — all **A**. `NavigationSplitView`/`SidebarView` is unreachable macOS/iOS scaffolding (dead, NTC-031).
- nested navigation: `NestedNavigationState` (no native nested-push signal) — **C (NTC-016)**.
- deep links: `UIApplicationDelegateAdaptor` + `DeepLinkHandler` — **B justified (NTC-017)**; multi-server `&server=` param ignored → **E (NTC-018)**.
- player presentation via `UIApplication.shared.connectedScenes` VC-walk, 8 duplicated sites → **C/E DRY (NTC-019)**.
- **Question — can native nav achieve equal-or-better?** Yes, and it is already used. No migration needed; the only custom nav (`NestedNavigationState`) is justified by a real tvOS gap. Consolidate the duplicated presentation boilerplate.

### Scope 3 — Focus System
- `@FocusState`/`.focusSection`/`.prefersDefaultFocus`/`.focusScope` — **A**.
- `FocusMemory` + `FocusRestorationPolicy` (persist focus across data reloads — native gap) — **C (NTC-020)**.
- `focusRecoveryWatchdog` (1.5s poll of `focusSystem.focusedItem`) → **E (NTC-021)**.
- `installSidebarFocusGuard`/`overrideSidebarFocusBehavior` (runtime swizzle of `shouldUpdateFocus` on internal `UICollectionView`) → **E (NTC-022)**.
- **Question — can native focus achieve equal-or-better reliability?** For placement/sections: yes (already used). For cross-reload persistence: **no** → keep `FocusMemory`. The two watchdog/swizzle workarounds are **not** reliable-native and must be root-caused/retired.

### Scope 4 — Home & Content UI
- hero (two-layer backdrop + parallax), preview carousel, EPG grid, `AppStoreActionButtonStyle`, dual-focus `EpisodeCard` — **C/D justified** (no native equivalent) — NTC-024.
- Continue Watching / landscape shelf / cards / adaptive tint / status labels / rating + technical badges / metadata hierarchy — **A/C** (custom presentation policies + tokens; no native equivalent).
- manual focus rings duplicating native (`SeasonPillButton`, `EpisodeCard` thumbnail border) → **B (NTC-023)**; `UIScreen.main.bounds` for hero height → **A (NTC-025)**.
- **Question — where should native replace custom layout/effects?** Only the small focus-ring duplications (NTC-023) and `UIScreen.main` reads (NTC-025). The bespoke hero/preview/EPG/cards are justified; **no feature removed**.

### Scope 5 — Playback
See the dedicated **Scope 5 per-component table** below (5 questions per component + the 16-item coverage). Summary: native `AVPlayerViewController` path is **A**; RPlayer/FFmpeg pipeline is **C** (native can't match); post-play overlay over native player is **E** (→ `AVContentProposal`, NTC-026); several player defects NTC-027.

### Scope 6 — Metadata & Presentation
See the dedicated **Scope 6 table** below. Summary: external metadata + chapters already native (**A**); content proposals should be adopted on the AVKit path (**E/NTC-026**); detail/cast/related/trailers are SwiftUI-custom with no native equivalent and no capability loss (**C**), except missing a11y labels (NTC-009).

### Scope 7 — Images & Caching
- `CachedAsyncImage` + `ImageCacheManager` (disk TTL/5GB/LRU, CGImageSource downsample, dedup, SHA-256 keys) vs `AsyncImage` (memory-only) — **C justified (NTC-028)**.
- Hero artwork / `AdaptiveTintLayer` (reuses cache, a11y-gated) — **A/C**. Top Shelf local-file handoff — **A**. Plex `/photo/:/transcode` sizing + TMDb paths — **A**.
- `CacheManager` `NSCache` has no `totalCostLimit` → **E (NTC-029)**.
- **Question — can native image caching achieve equal-or-better?** **No** — `AsyncImage` has no persistent disk cache/TTL/sizing. Custom is justified; fix the unbounded `NSCache` cost.

### Scope 8 — Accessibility
- Good: `ContinueWatchingCard`, `LandscapeContentCard`, `CastMemberCard`, `MediaDetailView` cards, `AdaptiveTintLayer` (Reduce Motion/Transparency/Increase Contrast) — **A**.
- Gaps: Settings + player controls have **zero** VoiceOver annotations (NTC-009); `MediaPosterCard`/`DiscoverTile`/EPG `ProgramCell` missing labels (NTC-009); `SettingsToggleRow` is a Button without `.isToggle`/value (NTC-010); Increase-Contrast/Reduce-Motion only in a few views (NTC-011).
- **Question — where does custom a11y compensate vs where should native reduce burden?** Native `Toggle`/`Picker` in Settings would remove hand-rolled a11y burden (NTC-010); custom cards must add explicit labels (native can't infer them) (NTC-009).

### Scope 9 — Swift Concurrency
- `SWIFT_VERSION 5.0`, no `SWIFT_STRICT_CONCURRENCY` → guarantees unenforced — **NTC-003 (E)**.
- `PlexNetworkManager`/`TMDBClient`/`PlexProvider`/`PlexMusicProvider`/`HomePerformanceTracer` `@unchecked Sendable` with unguarded mutable state — **NTC-004 (E/B)**.
- 53 `DispatchQueue` / 31 `Task.detached` / ~30 locks — non-FFmpeg → structured concurrency (**B**), FFmpeg/CoreMedia → keep (**C**) — **NTC-005**.
- `#if !RIVULET_FFMPEG` class splits are **A** (not duplicates) [verified] — NTC-006.
- **Swift 6 blockers:** NTC-003, NTC-004 (data races), NTC-005 (warnings-as-errors under strict mode), then NTC-001.

### Scope 10 — Security & Privacy
- token handling/redaction (`SensitiveDataRedactor`, `sanitizeSentryEvent`) — **A baseline**, but scope-closure `setExtra` bypasses `beforeSend` (NTC-036).
- URL construction: streaming URLs require `X-Plex-Token` query (native Plex pattern) — **C informational**; watchlist token-in-query — **C accepted**.
- `PlexThumbnailService` unconditional TLS trust → **E (NTC-007)** [verified]; scoped Plex trust too broad → **E (NTC-008)** [verified]; transcode `URLSession.shared` bypass → **E (NTC-002)** [verified].
- ATS `NSAllowsArbitraryLoads` → **E (NTC-034)**; Sentry `tracesSampleRate=1.0`+swizzling → **B (NTC-036)**.
- `PrivacyInfo.xcprivacy` present — **A** (review `ProductInteraction`/ratingKey disclosure, Low).
- **Classify:** native-compliant = redactor/Top-Shelf/privacy-manifest; custom-justified = streaming token-in-URL, IP-scoped self-signed trust; **defect** = NTC-002/007/008/034.

### Scope 11 — Project Structure
- targets: app + `TopShelfExtension` — **A**; entitlements over-broad (unused push/remote-notification, duplicate `aps-environment`) → **D (NTC-037)**.
- build settings: `SWIFT_VERSION 5.0` (NTC-003), no strict concurrency (NTC-003), no warnings-as-errors (NTC-038), spurious `IPHONEOS_DEPLOYMENT_TARGET` in tvOS configs (Low).
- deployment target tvOS 26.2 — **A** (intentional).
- **App Store risks:** NTC-007 (unconditional TLS), NTC-034 (ATS), entitlement trim. **Swift-6 blockers:** NTC-003/004/005.

---

## Scope 5 — Playback per-component table

5 questions: **Capability / Native AVKit equivalent / AVKit equal-or-better? / Lost if removed / Disposition (migrate·custom·fallback-only)**.

| Component | Capability | Native equivalent | AVKit equal/better? | Lost if removed | Disposition / Class |
| --- | --- | --- | --- | --- | --- |
| Native player (`NativePlayerViewController`) | barebones `AVPlayerViewController` | itself | n/a | — | **custom-native, keep (A)** |
| Direct play (native MP4 + native audio) | AVPlayer direct | AVPlayer | yes | nothing | **native-first (A)** |
| Direct stream / local remux (`LocalRemuxServer`) | FFmpeg MKV/DTS/TrueHD→fMP4 HLS, lossless | Plex HLS transcode | partial (Plex lossy/latency; DV P7 can't) | lossless DTS-HD; DV P7 zero-degrade path | **custom (C/A)** |
| HLS fallback / DirectPlayPipeline→HLS | post-crash fallback once | AVPlayer HLS | yes | nothing | **native consumes (A)** |
| RPlayer + DirectPlayPipeline | FFmpeg demux + AVSampleBuffer | AVPlayer | **no** | broad codec coverage | **custom (C)** |
| Dolby Vision P5/P8.1 | VideoToolbox native | AVPlayer | yes | — | **native (A)** |
| Dolby Vision P7 MEL / P8.6 | RPU rewrite→P8.1 (Dovi/HEVCNALParser) | none | **no** | DV P7/P8.6 plays SDR/fails | **custom (C)** |
| HDR / HDR10 | VideoToolbox + `DisplayCriteriaManager`/`AVDisplayManager` | auto on AVPlayer path | partial (manual for sample-buffer path) | correct dynamic range on RPlayer | **custom for RPlayer (C/B)** |
| Dolby Atmos (E-AC-3 JOC) | passthrough | AVPlayer passthrough | yes (native) | — | **native (A)**; device-verify |
| TrueHD | `FFmpegAudioDecoder`→PCM | none | **no** | TrueHD needs server transcode | **custom (C)** |
| DTS-HD | `FFmpegAudioDecoder`→PCM | none | **no** | DTS-HD lossy/transcode | **custom (C)** |
| DTS:X | `FFmpegAudioDecoder`→PCM (objects flattened) | none | **no** | DTS:X unплayable natively | **custom (C)** |
| PCM / FLAC | AudioToolbox native (FLAC) / FFmpeg (PCM variants) | partial | partial | exotic PCM | **native where possible (A/C)** |
| ASS subtitles | FFmpeg + overlay (styling) | AVPlayer legible | **no** | ASS styling | **custom (C)** |
| PGS subtitles | `FFmpegSubtitleDecoder` bitmap overlay | none | **no** | PGS entirely | **custom (C)** |
| SRT/WebVTT | parser/overlay; AVPlayer native too | AVPlayer legible | yes (AVPlayer path) | — | **native on AVKit path (A)** |
| Chapters | `navigationMarkerGroups` + thumbnails (`includeChapters=1`) | same | n/a | — | **native (A)** |
| Content proposals / post-play | custom SwiftUI overlay over native player | `AVContentProposal`+`AVContentProposalViewController`+delegate | **yes on AVKit path** | richer recs grid (mitigate via shared decision layer) | **migrate AVKit path (E → NTC-026)** |
| Custom player controls (`PlayerControlsOverlay` etc.) | transport/scrub/chapter colors/info for RPlayer | AVKit transport (AVPlayer path) | no for RPlayer; native already on AVKit path | RPlayer transport | **custom RPlayer-only (C)** |
| `NowPlayingService` | `MPNowPlayingInfoCenter` for RPlayer | auto on AVPlayerVC | no for RPlayer | Control Center/remote for RPlayer | **custom RPlayer-only (C)** |
| `URLSessionAVIOSource` | parallel ranged GET (4K-over-HTTP) | AVPlayer HTTP | no within RPlayer | 4K stalls | **custom (C)** |

---

## Scope 6 — Metadata & Presentation table

| Item | Current | Native alternative | Equal/better native? | Class | Recommendation |
| --- | --- | --- | --- | --- | --- |
| Detail page layout | bespoke SwiftUI (hero, scroll-reveal, season pills) | none (no native detail) | n/a | **C** | Keep; split file (NTC-030) |
| External metadata → player Info tab | `externalMetadata` (title/subtitle/desc/genre/rating/year/artwork, token-safe) | same | n/a | **A** | Keep; enrich release date/S·E (Low) |
| ContentPresentationPolicy / ContentStatusLabel | pure tested policies | none | n/a | **C** | Keep |
| Rating badge / technical badges (`MetadataBadge`) | shared rounded badge | none | n/a | **C** | Keep |
| Cast & crew | `castCrewRow` + photos + initials | none | n/a | **C** | Keep; add tap-through (backlog) |
| Related / recommendations | `PersonalizedRecommendationService` | Plex `includeRelated` hubs | partial (Plex pre-calculated, cheaper) | **C/B** | Evaluate `includeRelated` for post-play movies |
| Trailers / extras | Plex `Extras` + detail Play-Trailer | n/a | n/a | **A/C** | Keep |
| Post-play proposals | custom overlay | `AVContentProposal` (AVKit path) | yes on AVKit path | **E** | NTC-026 |
| Card/detail accessibility | combined labels (most) | n/a | n/a | **A/E** | Fill gaps (NTC-009) |

---

## Scope 13 — Findings (11-field format)

Fields: **Severity · Category · Files · Current · Native alternative · Capability comparison · Classification · Recommendation · Owner · Epic-4-blocker.** `[verified]` = re-read this pass.

**NTC-001 — ObservableObject → @Observable**
Sev Medium · State/SwiftUI · ~19 stores + ~50 `@StateObject`/`@ObservedObject` sites (UPVM, Discover/Home/LiveTV/Music/Settings VMs, SidebarView, etc.) · Current: `ObservableObject`+`@Published`+`@StateObject`/`@ObservedObject`/`@EnvironmentObject` · Native: `@Observable` + `@State`/`@Bindable`/`@Environment` · Capability: native equal-or-better (per-property invalidation, optionals/collections, tvOS 17+) — no loss · **B** · Recommend incremental migration (leaf VMs first; defer UPVM until concurrency settled) · Owner: modernization backlog · Epic-4: No.

**NTC-002 [verified] — Transcode requests use `URLSession.shared`**
Sev High · Reliability/Security · `PlexNetworkManager.swift:1640 (startTranscodeDecision), :1703 (stopTranscodeSession)` · Current: `URLSession.shared.data(for:)` (no cert delegate; errors swallowed) · Native: use `self.session` (configured self-signed-cert delegate) · Capability: native equal-or-better — only path that works on self-signed/`.plex.direct`/IP servers · **E** · Recommend route through `self.session` · Owner: Epic 4 playback/Epic 1 · Epic-4: not a blocker of policy slices, but a playback reliability defect to fix before E4-PR6 device validation.

**NTC-003 [verified] — Swift 6 mode not enforced**
Sev High · Build/Concurrency · `project.pbxproj` (all targets: `SWIFT_VERSION = 5.0`, no `SWIFT_STRICT_CONCURRENCY`) · Current: Swift 5 mode + approachable concurrency + `SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor` · Native: Swift 6 language mode + complete checking · Capability: goal; gated by NTC-004/005 · **E** · Recommend enable after cleanup (project-setting → explicit go) · Owner: Epic 5 · Epic-4: No.

**NTC-004 — `@unchecked Sendable` singletons with mutable state**
Sev High · Concurrency · `PlexNetworkManager.swift:28` (+ `TMDBClient:96`, `PlexProvider:12`, `PlexMusicProvider:11`, `HomePerformanceTracer:69` NSLock, `PlexWatchlistAPI:263`) · Current: `@unchecked Sendable`, unguarded `var`, cross-actor access · Native: `actor` or `@MainActor` isolation · Capability: native equal-or-better (race safety; networking already async) · **E/B** · Recommend isolate (`PlexNetworkManager` first) · Owner: modernization · Epic-4: No (Swift-6 prereq).

**NTC-005 — GCD/locks vs structured concurrency**
Sev Medium · Concurrency · 53 `DispatchQueue`, 31 `Task.detached`, ~30 locks across services/views; `.receive(on: DispatchQueue.main)` ×10 inside `@MainActor` · Current: GCD + ad-hoc locks · Native: actors + structured concurrency · Capability: equal-or-better for non-FFmpeg; FFmpeg/CoreMedia C-callback threading not modellable → keep · **B (non-FFmpeg) / C (FFmpeg)** · Recommend migrate non-FFmpeg; drop redundant main hops · Owner: modernization · Epic-4: No.

**NTC-006 [verified] — `#if !RIVULET_FFMPEG` class splits (not duplicates)**
Sev info · Concurrency/build · `RivuletPlayer.swift:14/57/1130`, `FFmpeg*.swift` · Current: conditional-compilation stub vs real impl · Native: n/a · Capability: correct pattern · **A** · Recommend none (corrects a scanner false-positive) · Owner: — · Epic-4: No.

**NTC-007 [verified] — Unconditional TLS trust (`PlexThumbnailService`)**
Sev High · Security · `PlexThumbnailService.swift:170 (TrustingSessionDelegate)` · Current: accepts any serverTrust for any host (no IP/host/port scope) · Native: scoped trust (IP-only) or OS evaluation · Capability: scoped/native equal-or-better (removes MITM on BIF) · **E** · Recommend reuse scoped Plex trust / OS eval · Owner: Epic 1/5 security · Epic-4: No; **App-Store blocker**.

**NTC-008 [verified] — Plex scoped trust too broad**
Sev High · Security · `PlexNetworkManager.swift:~2649`, `PlexAuthManager.swift:~924`, `ImageCacheManager.swift:~595` · Current: bypass for IP + `.plex.direct` (valid CA) + any port-32400 host · Native: IP-only bypass; OS-evaluate `.plex.direct` · Capability: native better for `.plex.direct` (real cert validation) · **E** · Recommend narrow scope + DRY one `PlexSSLTrust` delegate · Owner: Epic 1/5 · Epic-4: No; App-Store risk.

**NTC-009 — Missing VoiceOver labels (grid/EPG/player/settings)**
Sev High · Accessibility · `MediaPosterCard.swift:84`, `DiscoverTile.swift:30`, `GuideLayoutView ProgramCell:505`, `PlayerControlsOverlay.swift`, `PlayerProgressBar.swift`, `Views/Settings/**` · Current: no `.accessibilityLabel` on primary grid items, EPG cells, player controls, settings rows · Native: explicit `.accessibilityLabel`/`.accessibilityElement(children:.combine)` (and native controls for settings) · Capability: native controls reduce burden; custom cards need explicit labels · **E** · Recommend add labels; adopt native `Toggle`/`Picker` in settings · Owner: Epic 3/5 a11y · Epic-4: No; pre-ship blocker.

**NTC-010 — `SettingsToggleRow` is Button-as-Toggle**
Sev Medium · Accessibility/SwiftUI · `SettingsComponents.swift:133` (+ `SettingsPickerRow:216`, `SettingsListPickerRow:279`) · Current: `Button` flipping text, no `.isToggle`/`.accessibilityValue` · Native: `Toggle` / `Picker(.navigationLink)` · Capability: native equal-or-better (system focus + VoiceOver state) · **B/E** · Recommend native controls or add traits/value · Owner: Epic 3/5 · Epic-4: No.

**NTC-011 — Increase Contrast / Reduce Motion not systemic**
Sev Medium · Accessibility · `GlassRowStyle.swift:164` (0.08 resting fill), `SettingsView.animatePageSwap:987`, player controls · Current: only `AdaptiveTintLayer`/preview/hero/landscape honour these · Native: `@Environment(\.colorSchemeContrast)`/`accessibilityReduceMotion`/`accessibilityReduceTransparency` · Capability: native env equal · **E** · Recommend extend gating to glass surfaces + settings/player · Owner: Epic 3/5 · Epic-4: No.

**NTC-012 [verified] — SwiftData: no migration plan + fatalError**
Sev Critical · Persistence/data-integrity · `RivuletApp.swift:127 (Schema), :143 (ModelContainer), :145 (fatalError)` · Current: bare `Schema`/`ModelConfiguration`, crash on init failure · Native: `VersionedSchema` + `SchemaMigrationPlan` + graceful recovery · Capability: native equal-or-better (safe upgrades) · **E** · Recommend add migration plan; replace fatalError with store-reset path · Owner: Epic 5 / dedicated · Epic-4: No, but **gates any `@Model` change**.

**NTC-013 — Dead persistence graph + tokens in UserDefaults**
Sev Medium · Persistence/Security · `WatchProgress.swift`, IPTV `@Model`s, `LiveTVDataStore.swift:249` · Current: `WatchProgress`+`Channel`/`EPGProgram`/`FavoriteChannel`/`IPTVSource` registered but never queried/written; Live TV persists via `UserDefaults` JSON incl. `apiToken` · Native: SwiftData (activate) or remove; Keychain for tokens · Capability: equal · **E/B** · Recommend activate or remove (with migration); move tokens to Keychain · Owner: Epic 5 · Epic-4: No.

**NTC-014 — Unused `@Environment(\.modelContext)`**
Sev Low · Architecture · `ContentView.swift:17` · Current: captured, never used · Native: remove · Capability: n/a · **D** · Recommend delete · Owner: backlog · Epic-4: No.

**NTC-015 — `useApplePlayer` read via `UserDefaults.standard` (×5, non-reactive)**
Sev Medium · State · `ContentView:210`, `MediaDetailView:2063`, `PlexHomeView:372`, `PlexLibraryView:1256`, `UPVM:1063` · Current: direct reads, no reactivity · Native: single `@AppStorage`/observable settings · Capability: native equal-or-better · **B** · Recommend centralize · Owner: backlog · Epic-4: No.

**NTC-016 — `NestedNavigationState`**
Sev Low · Navigation · `NavigationEnvironment.swift:40` · Current: custom nested-push signal + `SidebarNavigationPolicy` · Native: none (no nested-NavigationStack signal in `TabView(.sidebarAdaptable)`) · Capability: native **cannot** match · **C** · Recommend keep; revisit if tvOS adds API · Owner: — · Epic-4: No.

**NTC-017 — Deep-link entry via `UIApplicationDelegateAdaptor`**
Sev Low · Navigation · `RivuletApp.swift` · Current: app-delegate URL + `NSUserActivity` → `DeepLinkHandler` · Native: `.onOpenURL` (no `NSUserActivity` coverage) · Capability: native **cannot** cover continuations · **C (B)** · Recommend keep · Owner: — · Epic-4: No.

**NTC-018 — Top Shelf `&server=` param ignored**
Sev Medium · Navigation/correctness · `DeepLinkHandler.swift:52`, `TopShelfExtension/ContentProvider.swift:48` · Current: `extractRatingKey` reads only `ratingKey`; playback uses currently-selected server · Native: parse + honor `server` · Capability: equal · **E** · Recommend wire server param (multi-server correctness) · Owner: Epic 4/5 · Epic-4: No.

**NTC-019 — Player/preview launch boilerplate triplicated**
Sev Medium · Navigation/DRY · Home/Library/Discover (8 sites) + `presentPreview` ×3 · Current: identical `connectedScenes` VC-walk + present · Native: one `WindowPresenter` utility · Capability: equal · **C/E (DRY)** · Recommend consolidate · Owner: backlog · Epic-4: No.

**NTC-020 — `FocusMemory`/`FocusRestorationPolicy`**
Sev Low · Focus · `Services/Focus/*` · Current: section-focus persistence across reloads · Native: `@FocusState`/`.focusSection` (no cross-reload persistence) · Capability: native **cannot** match · **C** · Recommend keep (tested) · Owner: — · Epic-4: No.

**NTC-021 — `focusRecoveryWatchdog` polling**
Sev High · Focus · `TVSidebarView.swift:557` · Current: 1.5s poll of `focusSystem.focusedItem`, `resetFocus` if nil · Native: native focus engine + targeted reset at causal site · Capability: native better once root-caused · **E** · Recommend root-cause; remove poll · Owner: Epic 4/5 · Epic-4: No (interaction risk).

**NTC-022 — `shouldUpdateFocus` runtime swizzle**
Sev High · Focus/maintainability · `TVSidebarView.swift:586` · Current: `class_replaceMethod` on internal `UICollectionView` subclass found via width/x heuristic · Native: `.focusSection()` containment / native API · Capability: native better (no SPI/UB) · **E** · Recommend replace; remove swizzle · Owner: Epic 4/5 · Epic-4: No (breaks on sidebar restructure).

**NTC-023 — Manual focus rings duplicating native**
Sev Low · UI · `MediaDetailView.swift:3275 (SeasonPillButton), :3413 (EpisodeCard thumb)` · Current: manual `@FocusState`+scale+border · Native: `.buttonStyle(.card)`/`.hoverEffect(.highlight)` · Capability: native equal · **B** · Recommend adopt native effects · Owner: backlog · Epic-4: No.

**NTC-024 — Bespoke UI (EPG grid / preview carousel / hero / dual-focus card / AppStoreActionButtonStyle)**
Sev info · UI · `GuideLayoutView`, `PreviewOverlayHost`, `Hero/*`, `MediaDetailView EpisodeCard`, `GlassRowStyle` · Current: custom · Native: none equivalent · Capability: native **cannot** match · **C/D** · Recommend keep · Owner: — · Epic-4: No.

**NTC-025 — `UIScreen.main.bounds` for hero height**
Sev Low · UI · `PlexHomeView:693`, `PlexLibraryView:473`, `DiscoverView:39` · Current: deprecated `UIScreen.main` · Native: existing `GeometryReader` `geo.size` · Capability: native better · **A→fix** · Recommend use GeometryReader · Owner: backlog · Epic-4: No.

**NTC-026 — Post-play overlay over native player**
Sev Medium · Playback/HIG · `Views/Player/PostVideo/*`, `UniversalPlayerView` · Current: custom SwiftUI overlay over `AVPlayerViewController` · Native: `AVContentProposal`+`AVContentProposalViewController`+delegate (AVKit path) · Capability: native **better on AVKit path** (system-shrunk video, native focus); RPlayer can't · **E** · Recommend E4-PR9: shared decision layer → native proposal on AVKit path + overlay for RPlayer (`DEBT-E4-AVKIT-001`) · Owner: Epic 4 · Epic-4: it IS slice E4-PR9.

**NTC-027 — Player defects**
Sev Medium · Playback · `UPVM:1929 (segments.first!)`, `:1908 (as! AVMetadataItem)`, `PlayerControlsOverlay:559 (UIScreen.main)`, ~14 `DispatchQueue.main.asyncAfter` focus hacks, `print()` of internal state · Current: force-unwrap/cast, deprecated API, timing hacks, unstructured logs · Native: guard/`if let`, GeometryReader, `Task.yield`, `playerDebugLog` · Capability: native equal-or-better · **E/C** · Recommend harden · Owner: Epic 4 · Epic-4: No.

**NTC-028 — `CachedAsyncImage`/`ImageCacheManager`**
Sev info · Images · `Views/Components/CachedAsyncImage.swift`, `Services/Cache/ImageCacheManager.swift` · Current: disk TTL/5GB/LRU/downsample, actor-isolated · Native: `AsyncImage` (memory-only) · Capability: native **cannot** match · **C** · Recommend keep · Owner: — · Epic-4: No.

**NTC-029 — `CacheManager` NSCache no `totalCostLimit`**
Sev Medium · Performance · `CacheManager.swift:32` · Current: count-limit only; unbounded bytes · Native: `totalCostLimit` + cost · Capability: native equal-or-better · **E** · Recommend set cost limit · Owner: backlog · Epic-4: No.

**NTC-030 — `MediaDetailView.swift` 3825 lines**
Sev High · Maintainability · `MediaDetailView.swift` · Current: monolith hitting type-checker budget · Native: extract sub-views · Capability: n/a · **E** · Recommend split (EpisodeCard/EpisodeRow/Season*) · Owner: backlog · Epic-4: friction risk.

**NTC-031 — Dead code**
Sev Low · Maintainability · `PlayerProgressBar.swift`, `TrackSelectionSheet.swift`, `VideoInfoOverlay.swift`, `ParallaxPosterImage/LayerStack`, `ContentRow`, `SidebarView`/`NavigationSplitViewContent` (tvOS-unreachable) · Current: no live call sites · Native: remove · Capability: n/a · **D** · Recommend confirm then delete · Owner: backlog · Epic-4: No.

**NTC-032 — `PlexNetworkManager` God object (2719 lines)**
Sev Medium · Architecture · `PlexNetworkManager.swift` · Current: auth/discovery/browse/streaming/LiveTV/progress/XML in one singleton · Native: domain clients (pattern started: `PlexWatchlistAPI`/`PlexTimelineReporter`) · Capability: n/a · **E** · Recommend extract domains · Owner: backlog · Epic-4: No.

**NTC-033 — Regex-per-call hotspots**
Sev Medium · Performance · `M3UParser:186` (~3000 compiles/500ch), `PlexNetworkManager.parseHomeUsersXML:2445`, `PlexAuthManager.extractPlexDirectHash:496` (locale-fragile) · Current: `NSRegularExpression` per call · Native: static `Regex`/`XMLParser` · Capability: native equal-or-better · **A/B** · Recommend precompile/native parse · Owner: backlog · Epic-4: No.

**NTC-034 [verified-ish] — ATS arbitrary loads**
Sev Medium · Security/App-Store · `Info.plist:21` · Current: `NSAllowsArbitraryLoads=true` (+ `NSAllowsLocalNetworking`, m3u4u exception) · Native: `NSAllowsLocalNetworking` + scoped exceptions only · Capability: native mostly-equal (LAN http covered) · **E** · Recommend remove blanket; document residual (`DEBT-E0-001`) · Owner: Epic 1/5 · Epic-4: No; App-Store blocker.

**NTC-035 — XMLTV drops timezone offsets**
Sev Medium · Data correctness · `XMLTVParser.swift:295` · Current: hand parser hardcodes UTC, ignores `±HHMM` · Native: `DateFormatter "yyyyMMddHHmmss Z"` · Capability: native correct · **E** · Recommend parse offset · Owner: backlog · Epic-4: No.

**NTC-036 — Sentry exposure surface**
Sev Medium-High · Security/telemetry · `RivuletApp.swift:59 (tracesSampleRate=1.0), :65 (enableSwizzling)`, scope-closure `setExtra(url.path)` (`PlexLiveTVModels:320`, `MultiStreamViewModel:296`, `HLSSegmentFetcher:189`) · Current: full tracing + scope extras bypass `beforeSend` · Native: lower sample rate; route scope extras through redactor; confirm span scrubbing · Capability: equal · **B** · Recommend tighten · Owner: Epic 1/4 · Epic-4: No.

**NTC-037 — Over-broad entitlements**
Sev Low · Security/App-Store · `Rivulet.entitlements` · Current: unused `remote-notification`+`aps-environment` (duplicate keys) · Native: remove unused · Capability: n/a · **D** · Recommend trim · Owner: backlog · Epic-4: No.

**NTC-038 — No warnings-as-errors**
Sev Low · Build/process · `project.pbxproj` · Current: no `SWIFT_TREAT_WARNINGS_AS_ERRORS` · Native: enable · Capability: n/a · **E (process)** · Recommend enable post-cleanup · Owner: Epic 5 · Epic-4: No.

**NTC-039 — Unstable `Identifiable.id` fallbacks**
Sev Medium · Models/SwiftUI · `PlexMetadata.swift:40/63/204 (UUID() fallback), :17/24 (composite collide)` · Current: `UUID().uuidString` per access; "unknown" collisions · Native: stable hash · Capability: native better (diffing) · **C** · Recommend stable ids · Owner: backlog · Epic-4: No.

**NTC-040 — `TMDBConfig.proxyBaseURL` hardcoded personal Worker**
Sev Medium · Config/ops · `TMDBConfig.swift:12` · Current: `baingurley.workers.dev` baked in, no override · Native: config/remote override · Capability: n/a · **E (ops)** · Recommend configurable + fallback before public release · Owner: Epic 5 · Epic-4: No.

---

## Scope 14 — Required matrix (full)

| Component | Current Implementation | Native Alternative | Native Equal/Better? | Classification | Recommendation |
| --- | --- | --- | --- | --- | --- |
| App lifecycle/scene | SwiftUI App+WindowGroup+AppDelegateAdaptor | same | n/a | A | Keep |
| Navigation (sidebar/tabs/stack) | TabView(.sidebarAdaptable)+NavigationStack | same | n/a | A | Keep |
| Nested-navigation signal | NestedNavigationState | none | No | C | Keep |
| Deep links | AppDelegateAdaptor+DeepLinkHandler | .onOpenURL | No (no NSUserActivity) | C | Keep; fix server param (E) |
| State layer | ObservableObject+@StateObject | @Observable+@State | Yes | B | Migrate (NTC-001) |
| Settings reads | UserDefaults.standard ×5 | @AppStorage | Yes | B | Centralize (NTC-015) |
| Persistence | SwiftData bare Schema+fatalError | VersionedSchema+MigrationPlan | Yes | E | Migration plan (NTC-012) |
| Dead model graph | WatchProgress+IPTV @Models unused | SwiftData or remove | Yes | E/B | Activate/remove (NTC-013) |
| Focus placement | @FocusState/.focusSection | same | n/a | A | Keep |
| Focus persistence | FocusMemory/FocusRestorationPolicy | none | No | C | Keep |
| Focus watchdog/swizzle | poll+class_replaceMethod | native engine | No today | E | Root-cause/retire (NTC-021/022) |
| Hero/preview/EPG/dual-focus card | bespoke SwiftUI | none | No | C/D | Keep |
| Manual focus rings | @FocusState+border | .card/.hoverEffect | Yes | B | Native (NTC-023) |
| Adaptive tint/badges/status/tokens | custom SwiftUI | none | n/a | C | Keep |
| Hero height | UIScreen.main.bounds | GeometryReader | Yes | A→fix | Fix (NTC-025) |
| Native video player | barebones AVPlayerViewController | same | n/a | A | Keep |
| RPlayer/FFmpeg/Dovi/remux/FFmpeg-subs | custom pipeline | AVKit | No | C | Keep |
| Chapters | navigationMarkerGroups | same | n/a | A | Keep |
| External metadata | externalMetadata (token-safe) | same | n/a | A | Keep |
| Post-play | overlay over native player | AVContentProposal | Yes (AVKit) | E | NTC-026 |
| Player controls (RPlayer) | custom transport | AVKit transport | No (RPlayer) | C | Keep |
| Transcode requests | URLSession.shared | self.session (cert delegate) | Yes | E | Fix (NTC-002) |
| Image cache | CachedAsyncImage/ImageCacheManager | AsyncImage | No | C | Keep |
| Memory cache | NSCache no cost limit | totalCostLimit | Yes | E | Fix (NTC-029) |
| TLS trust (thumbnails) | accept any cert | scoped/OS eval | Yes | E | Fix (NTC-007) |
| TLS trust (Plex scoped) | IP+.plex.direct+port32400 | IP-only+OS eval | Yes (narrower) | E | Tighten (NTC-008) |
| ATS | NSAllowsArbitraryLoads | NSAllowsLocalNetworking+exceptions | Mostly | E | Tighten (NTC-034) |
| Sentry | tracesSampleRate=1.0+swizzling | scoped/sanitized | Yes | B | Tighten (NTC-036) |
| Concurrency (@unchecked singletons) | unguarded mutable | actor/@MainActor | Yes | E/B | Isolate (NTC-004) |
| Concurrency (GCD/locks non-FFmpeg) | DispatchQueue/Task.detached | actors/structured | Yes | B | Migrate (NTC-005) |
| Concurrency (FFmpeg/CoreMedia) | locks/nonisolated(unsafe) | — | No | C | Keep |
| Swift language mode | 5.0 | 6.0+strict | Yes | E | After cleanup (NTC-003) |
| Top Shelf | TVTopShelfContentProvider | same | n/a | A | Keep; displayAction/server fix |
| AppIntents/Keychain/Vision/OSSignposter | native frameworks | same | n/a | A | Keep |
| Settings controls | Button-as-Toggle | Toggle/Picker | Yes (a11y) | B/E | Native (NTC-010) |
| Accessibility (cards/EPG/player/settings) | missing labels | explicit/native | Yes | E | Add (NTC-009/011) |
| Recommendations | bespoke service | Plex includeRelated | Partial | C/B | Evaluate |
| XMLTV dates | UTC-hardcoded | DateFormatter Z | Yes | E | Fix (NTC-035) |
| Identifiable ids | UUID()/collide | stable hash | Yes | C | Fix (NTC-039) |
| God objects/dead code/DRY | PlexNetworkManager 2719L, MediaDetailView 3825L, dead files, triplicated launch | extract/remove/share | n/a | E/D | Refactor (NTC-019/030/031/032) |

---

## Scope 15 — Remediation roadmap

**Priority 1 — defects / risk (schedule regardless of Epic):**
- NTC-007 unconditional TLS trust (App-Store/security)
- NTC-008 tighten Plex trust + DRY one delegate
- NTC-002 transcode `self.session` (playback reliability; pre-E4-PR6)
- NTC-012 SwiftData migration plan + graceful init (data integrity; gates model changes)
- NTC-034 ATS scoping; NTC-036 Sentry sample-rate/span scrubbing

**Priority 2 — native migrations that cut custom complexity, no feature loss:**
- NTC-021/022 root-cause + retire focus watchdog/swizzle
- NTC-026 E4-PR9 native `AVContentProposal` post-play
- NTC-004 isolate singletons → NTC-005 non-FFmpeg structured concurrency → NTC-003 Swift 6 mode
- NTC-009/010/011 accessibility (cards, EPG, player, settings, contrast/motion)
- NTC-035 XMLTV timezone; NTC-029 cache cost limit; NTC-013 dead persistence + Keychain tokens; NTC-018 Top Shelf server param

**Priority 3 — polish / backlog:**
- NTC-001 `@Observable` migration; NTC-015 settings reads; NTC-039 stable ids
- NTC-030/032 split God-objects; NTC-019 shared WindowPresenter; NTC-031 remove dead code (after confirmation); NTC-023/025 native focus effects/GeometryReader
- NTC-033 regex; NTC-037 entitlement trim; NTC-038 warnings-as-errors; NTC-040 proxy override; metadata enrichment

**No recommendation reduces parity.** Custom kept (native cannot match): RPlayer/FFmpeg/Dovi/remux/FFmpeg-subs, image disk cache, FocusMemory, design tokens/tint/badges/status, EPG grid, preview carousel, hero, AppIntents/Keychain/Vision/OSSignposter, IP-scoped self-signed trust, NestedNavigationState, AppDelegate deep-link adaptor.

---

## Epic 4 blockers

**None block Epic 4's remaining pure-policy slices (E4-PR5).** NTC-026 *is* E4-PR9.
NTC-002 is a playback reliability defect worth fixing before E4-PR6 device
validation. NTC-007/008/012/034/009 are **Epic-5 / App-Store pre-ship** blockers.
The AVKit default flip (E4-PR6) stays corpus/device-gated.

*Aggregated from 8 read-only domain sweeps; the highest-severity new claims were
code-verified [verified]. [scanner]-only items carry file:line and should be
root-cause-confirmed at fix time. No functionality is recommended for removal to
become "more native"; every retained-custom item has a stated capability gap. No
code, settings, or playback changed.*
