# Apple AVKit Playback Reference Audit (Epic 4)

Date: 2026-06-02
Status: audit + implementation-mapping only. No playback code changed; no routing
change; no AVKit default flip. Public APIs / public design guidance only — no
private APIs, no Apple branding, no Apple-TV-integration or partner-only claims.

## 0. Source verification

Live-verified via the Apple-docs reader (developer.apple.com is a JS SPA that a
plain fetch can't read; the structured reader returned full article bodies):

| Apple page | Verified | Key public APIs confirmed |
| --- | --- | --- |
| Customizing the tvOS Playback Experience | Yes | `AVPlayerViewController`; title view from `commonIdentifierTitle` + `iTunesMetadataTrackSubTitle`; `externalMetadata`; `transportBarCustomMenuItems`; `customInfoViewControllers`; `infoViewActions`; `contextualActions` (Skip) |
| Presenting Content Proposals in tvOS | Yes | `AVContentProposal`; `AVPlayerItem.nextContentProposal`; `AVContentProposalViewController` (+ `preferredPlayerViewFrame`, `dismissContentProposal(for:animated:completion:)`); delegate `playerViewController(_:shouldPresent:)` / `(_:didAccept:)` / `(_:didReject:)` |
| Presenting Navigation Markers | Yes | `AVPlayerItem.navigationMarkerGroups`; `AVNavigationMarkersGroup`; `AVTimedMetadataGroup` (+ `AVMetadataItem` title, `commonIdentifierArtwork` thumbnail) |
| AVPlayerViewControllerDelegate | Yes | protocol surface (tvOS 9+) |
| AVKit Metadata Identifiers / AVPlayerViewController / AVKit overview | Partial | identifier constants taken from established public AVFoundation/AVKit API (`AVMetadataIdentifier`) — already used in code |
| Human Interface Guidelines | Not individually rendered | applied from established public HIG principles; flagged where unverified |

---

## 1. AVKit-first native player strategy

Criteria are already encoded by the E4-PR3 `PlaybackRoutingPolicy` (pure, tested,
flag-gated; `avKitFirst` default off until E4-PR6). This audit confirms they
match Apple guidance.

| Route criterion | Player | Rationale |
| --- | --- | --- |
| Native MP4/MOV/M4V + native audio (AAC/AC3/EAC3/ALAC/etc.), no DV P7 | **AVPlayerViewController direct** | Native transport, Siri Remote, Now Playing, PiP, Info/Chapters panels (tvOS 15 redesigned UI). Lowest latency. |
| Non-native container / non-native audio, `useApplePlayer` + no DV | **AVKit via Plex HLS / local remux** | AVKit consumes server-remux/transcode or local-remux HLS end-to-end. |
| DV P7 MEL / P8.6, lossless/exotic audio (TrueHD/DTS-HD/DTS:X/PCM/FLAC), high-bitrate 4K HEVC/DV over HTTP | **RPlayer (capability fallback)** | AVKit can't faithfully present these; RPlayer's FFmpeg pipeline can (RPU rewrite, client decode, `URLSessionAVIOSource`). |
| Unsupported video codec (MPEG-2/VC-1/VP9/AV1) or HLG | **AVKit via Plex transcode (HLS)** | Only AVPlayer triggers tvOS HLG→HDR10; no Apple TV decoder for those codecs. |

**Why AVKit-first improves UX:** the tvOS 15 redesigned player (native transport
bar, voice/Siri-Remote commands, Now Playing, PiP, Info + Chapters tabs, AirPlay
A/V sync) is free and familiar; it reduces the custom-UI maintenance surface.
**Preserve native visuals** on the AVPlayer path (transport, Info/Chapters tabs,
contextual Skip). **Custom UI still required** only on the RPlayer path
(`SampleBufferDisplayView` + custom controls — RPlayer is not an
`AVPlayerViewController`) and for the cross-player post-play overlay (§4).

Conclusion: AVKit-first strategy is correct and already modelled; the flip
(E4-PR6) stays corpus/device-gated.

---

## 2. Apple native player GUI / UX (current state)

`NativePlayerViewController` is a **barebones `AVPlayerViewController` subclass** —
the correct HIG posture:

| Behaviour | Status |
| --- | --- |
| Native transport controls (scrub/play/pause/skip) | ✅ native (no custom overlay) |
| Siri Remote behaviour | ✅ native |
| Now Playing / `MPRemoteCommandCenter` / audio session | ✅ native (explicitly not overridden) |
| AirPlay A/V sync | ✅ native |
| Native subtitle/audio selection UI | ✅ native (AVKit transport menu) |
| Skip (intro/credits) | ✅ native `contextualActions` (the Apple-recommended pattern) |
| External metadata (title/subtitle/desc/genre/rating/year/artwork) | ✅ set via `externalMetadata` (§5) |
| Native chapters | ✅ `navigationMarkerGroups` (§6) |

**Deviations:** (a) the post-play / next-up experience is a **custom SwiftUI
overlay** (`PostVideoSummaryView`) drawn **over** the native `AVPlayerViewController`
— this is itself a **non-native deviation**: Apple's model is `AVContentProposal`,
where the *system* shrinks the video and presents the proposal with native focus /
Siri-Remote / auto-accept (§4). Under the now-ratified AVKit-first policy the
AVPlayer path is the default/majority, so the native proposal is the correct
primary presenter, not the custom overlay. (b) The RPlayer path is fully custom
(unavoidable). Correcting (a) is the substance of §4.

---

## 3. AVPlayerViewControllerDelegate opportunities

`NativePlayerViewController` currently sets **no delegate** — a real gap, not a
non-issue. Setting `AVPlayerViewControllerDelegate` is **required** to deliver the
native post-play UX on the AVKit (default/majority) path:

| Delegate use | Opportunity | Recommendation |
| --- | --- | --- |
| Content proposals (`playerViewController(_:shouldPresent:)` / `(_:didAccept:)` / `(_:didReject:)`) | Native next-episode / next-up proposal — system shrinks video to `preferredPlayerViewFrame`, native focus + Siri Remote + auto-accept interval | **Adopt on the AVKit path** (the default under AVKit-first). Set `AVPlayerItem.nextContentProposal`, implement the delegate, present an `AVContentProposalViewController`. Share the *decision/data* with the RPlayer overlay (§4) — one decision, two presenters. |
| Full-screen / transition (`willBeginFullScreenPresentation` / `willEnd…`) | Coordinate dismissal, focus return, backdrop | **Evaluate in the post-play slice** — needed for clean proposal→dismiss / focus handoff, not "low priority". |
| Picture in Picture delegate hooks | PiP start/stop + UI restore | **Evaluate** (AVPlayerViewController gives PiP for free; restore needs the delegate). Scope explicitly, don't hand-wave. |
| `playerViewController(_:willResumePlaybackAfterUserNavigatedFromTime:to:)` | Resume coordination after scrub/skip/proposal navigation | **Evaluate** alongside the E4-PR4 resume policy wiring. |

Conclusion: delegate work **is** in scope — at minimum the content-proposal hooks
for native post-play on the AVKit path; full-screen/PiP/resume hooks are to be
scoped in the post-play slice, not dismissed.

---

## 4. Post-play / next-up UX

**Already implemented** as a custom overlay (`Views/Player/PostVideo/`):
`PostVideoSummaryView`, `NextEpisodeCard`, `EpisodeSummaryOverlay`,
`MovieSummaryOverlay`, `CountdownRing`. Triggered by credits-marker / near-end
detection in `UniversalPlayerViewModel` (`postVideoState`,
`triggerPostVideoTransition`). It already follows Apple's content-proposal *model*
(artwork + title + Play Next + Back) while working across BOTH players.

Apple reference (verified): `AVContentProposal` → `AVPlayerItem.nextContentProposal`
→ `AVContentProposalViewController` (override `preferredPlayerViewFrame` to shrink
the video) + delegate accept/reject. The system presents it over the playing
video with native focus/Siri-Remote behaviour and an optional auto-accept
interval.

**Corrected target architecture (one decision, two presenters):**

- A **shared, Plex-powered post-play decision layer** (pure, testable) resolves
  *what* to propose and *when*: next episode (on-deck / next chronological),
  related for movies (`includeRelated` similar/director hubs), artwork, titles,
  S/E metadata, Play-Next vs Replay, and whether to auto-advance. This layer is
  player-agnostic.
- **AVKit path (default/majority under AVKit-first): native presentation.** Set
  `AVPlayerItem.nextContentProposal`, implement the delegate, present an
  `AVContentProposalViewController` (system shrinks the video). This is the
  first-party UX and removes the current custom-overlay-over-native deviation.
- **RPlayer path (fallback): the existing custom overlay**, fed by the *same*
  decision layer, since native proposals aren't available there.

Behaviour rules (both presenters): episodes → next episode (artwork/title/S·E),
Play Next, Back/Dismiss, **no surprise autoplay** (auto-accept/countdown must be
cancellable and/or setting-gated), **update watch-state before the proposal**
(Epic 1 consume-only); movies → More Like This / Replay / Back, no fake "next".

Plex data (all available): on-deck / next episode, `includeRelated` hubs,
watched/progress, `ratingKey`, grandparent/parent metadata, artwork,
duration/`viewOffset`.

**Recommendation:** YES — a dedicated Epic 4 slice. It is **not** "keep the custom
overlay everywhere": it builds the shared decision layer + adopts the **native
`AVContentProposal`** on the AVKit path and reuses the overlay only as the RPlayer
presenter. (My earlier "do not migrate to `AVContentProposal`" was wrong — it
optimised for the RPlayer minority path and entrenched a non-native overlay on the
default path.)

---

## 5. AVKit metadata identifiers

`UniversalPlayerViewModel.buildExternalMetadata()` already populates the player
item, set via `item.externalMetadata`. Mapping audit (Plex → public
`AVMetadataIdentifier`):

| Field | Identifier used | Status |
| --- | --- | --- |
| Title (episode "S E · title" / movie title) | `commonIdentifierTitle` | ✅ |
| Show name (episodes) | `iTunesMetadataTrackSubTitle` | ✅ (drives the title view subtitle per Apple doc) |
| Description | `commonIdentifierDescription` | ✅ |
| Genre | `quickTimeMetadataGenre` | ✅ |
| Content rating | `iTunesMetadataContentRating` | ✅ |
| Year | `commonIdentifierCreationDate` (year string) | ⚠️ minor — a full release date would be more precise |
| Artwork | `commonIdentifierArtwork` (in-memory JPEG of the now-playing image) | ✅ local image data — no URL/token/path |
| Season / episode numbers | (folded into title string) | 🔶 backlog — dedicated season/episode metadata could enrich the Info tab |

**Token / URL safety: confirmed clean.** No Plex token, server URL, stream URL, or
file path is placed into any metadata item — title/desc/genre/rating are plain
strings; artwork is JPEG bytes of an in-memory `UIImage`. (Consistent with the
E4-PR1 observability close.)

Conclusion: metadata population is already correct and safe. Only minor
enrichment (precise release date, dedicated S/E identifiers) is backlog — a small
optional slice, not a gap.

---

## 6. Navigation markers / chapters

**Already native.** `UniversalPlayerViewModel.buildNavigationMarkers()` sets
`item.navigationMarkerGroups = [AVNavigationMarkersGroup(timedNavigationMarkers:
[AVTimedMetadataGroup …])]`, exactly the Apple model:

- `PlexNetworkManager` requests `includeChapters=1`.
- Chapter title → `AVMetadataItem` (`commonIdentifierTitle`); start/duration →
  `CMTimeRange`; thumbnail (when present) → `commonIdentifierArtwork` on the timed
  group (`chapterThumbnails` fetched with bounded concurrency).
- A second path builds marker groups from intro/credits markers too.

This is the native Chapters panel — **not** a custom reimplementation on the
AVPlayer path. The RPlayer path has its own chapter handling (custom, required).

Conclusion: chapters are correctly native on the AVKit path; **no rewrite and no
new slice needed** for Epic 4 beyond on-device verification. (RPlayer chapter
polish, if any, is separate.)

---

## 7. Plex wiring audit

| Input | Status | Note |
| --- | --- | --- |
| Media stream metadata (codec/container/streams) | **Already wired** | `ContentRouter` + `MediaSource`; drives routing. |
| Direct-play eligibility | **Already wired** | `ContentRouter` native-container/native-audio check. |
| Direct stream / transcode URL | **Already wired** | HLS via `PlexNetworkManager`; full client profile for DVB. |
| Audio streams | **Already wired** | Track selection (AVKit menu / RPlayer). |
| Subtitle streams (SRT/ASS/PGS) | **Already wired** | Subtitle pipeline; not a routing input. |
| Chapters | **Already wired** | `includeChapters=1` → native `navigationMarkerGroups` (§6). |
| Extras / trailers | **Already wired** | Plex `Extras` (`extraType==1`/`subtype=="trailer"`); detail Play-Trailer. |
| Related items (More Like This) | **Wired (own service)** | `PersonalizedRecommendationService`; consider Plex `includeRelated` for post-play movies (§4) — future backlog. |
| Next episode / on-deck | **Already wired** | Detail next-up + post-play next episode. |
| Watch progress / `viewOffset` | **Already wired** | E4-PR4 resume policy; Epic 1 reporting. |
| Content rating | **Already wired** | `iTunesMetadataContentRating` (§5) + detail/hero badge (ADO-06). |
| Technical format badges | **Already wired** | `TechnicalBadgePolicy` (display); capability badges = Epic 4 future. |
| Token / stream URL in metadata or telemetry | **Safe** | Verified clean (E4-PR1, §5). |

No item is wired incorrectly or unsafely. Only `includeRelated`-for-post-play-
movies is a future-backlog enhancement.

---

## 8. Human Interface Guidelines alignment

(Applied from established public HIG principles; the HIG landing page was not
individually machine-rendered this pass.)

| HIG principle | Rivulet | Verdict |
| --- | --- | --- |
| Minimize custom controls / use system controls | Native `AVPlayerViewController` on the AVKit path; custom only for RPlayer | ✅ |
| Preserve Siri Remote expectations | Native transport on AVKit path | ✅ |
| Focus clarity | Native focus on AVKit; custom overlays use `@FocusState` | ✅ (device-verify) |
| Avoid surprise autoplay | Post-play `CountdownRing` exists | 🔶 verify it is cancellable / setting-gated (§4) |
| Legible overlays / no clutter | Post-play overlay + adaptive tint (ADO-06) | ✅ |
| Accessibility: Reduce Motion / Reduce Transparency / Increase Contrast | Adaptive tint a11y-gated (ADO-06); preview reduce-motion (E3-PR3) | ✅ for content surfaces; player overlays = device-verify (`DEBT-E0-007`) |

---

## 9. Epic 4 decomposition impact

| Candidate | Decision |
| --- | --- |
| AVKit metadata population | **Already done** (§5). Optional tiny enrichment (release date, S/E identifiers) → backlog, not a slice. |
| Content proposals / post-play | **New slice (E4-PR9)** — build a shared Plex post-play decision layer + adopt **native `AVContentProposal`** on the AVKit (default) path via `AVPlayerViewControllerDelegate`, and reuse the existing overlay as the RPlayer presenter. Replaces the current custom-overlay-over-native deviation. No-surprise-autoplay, related-for-movies via `includeRelated`, watch-state-before-proposal. |
| Native chapter markers | **Already done natively** (§6). No slice (device-verify only). |
| Player GUI conformity | **Already conformant** (§2). No slice (device-verify only). |
| Plex metadata wiring | **Already wired** (§7). No slice. |
| Subtitle/audio UI parity | Stays **E4-PR7** (existing plan). |

Net: metadata, chapters, and the native GUI are already native (device-verify
only). The genuinely new build is **E4-PR9 — native post-play** (shared decision
layer + `AVContentProposal` on the AVKit path + delegate + RPlayer overlay reuse),
which also fixes a real native deviation (custom overlay over the native player).
This is a build, not just a "verify".

---

## 10. Recommended next Epic 4 slice

Continue the planned ladder: **E4-PR5 — interruption/failure recovery policy**
(pure, no corpus/device dependency), which also naturally owns the deferred
`rebuffer`/`stall`/`recovered` telemetry. Schedule the **post-play UX
standardization** slice (this audit's net-new finding) after E4-PR5, before or
alongside E4-PR7. The AVKit default flip (E4-PR6) and any device-verification of
the already-native metadata/chapters/GUI remain corpus/device-gated.

*Rivulet is a distinct Plex/TMDb tvOS app. No Apple branding, private APIs,
partner features, or Apple-TV-integration claims are adopted.*
