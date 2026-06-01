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
overlay** (`PostVideoSummaryView`) presented in `UniversalPlayerView`, not AVKit
content proposals — deliberate, so it works identically on the RPlayer path (§4);
(b) the RPlayer path is fully custom (unavoidable). No unnecessary custom overlays
sit on the native player.

---

## 3. AVPlayerViewControllerDelegate opportunities

`NativePlayerViewController` currently sets **no delegate**. Public hooks worth
considering (AVKit-path only — none would apply to RPlayer):

| Delegate use | Opportunity | Recommendation |
| --- | --- | --- |
| Content proposals (`shouldPresent`/`didAccept`/`didReject`) | Native next-episode proposal | **Do not adopt as the primary** — it only works on the AVPlayer path and would fragment post-play across the two players. Keep the cross-player custom overlay (§4). Optional later: native proposal on the AVKit path only. |
| Full-screen / transition (`willBeginFullScreenPresentation`/`willEndFull…`) | Coordinate dismissal/focus | Low priority; current dismissal works. |
| Picture in Picture delegate hooks | PiP restore | Future; not requested. |
| `willResumePlaybackAfterUserNavigatedFromTime` etc. | Resume after seek/skip | Covered by existing logic; not needed now. |

Conclusion: no delegate work is required for parity. A delegate is only needed if
a native AVKit-path content proposal is later desired as an enhancement.

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
the video) + delegate accept/reject. Rivulet's equivalent is powered by Plex data,
not AVKit, by design.

To audit/standardize (a candidate Epic 4 slice — not a rebuild):

- Episodes: propose next episode (artwork, title, S/E metadata), Play Next, Back/
  Dismiss; **no surprise autoplay** — verify the `CountdownRing` auto-advance is
  user-cancellable and/or gated by a setting; **update watch-state before the
  proposal** where appropriate (Epic 1 boundary respected).
- Movies: propose **More Like This / related** (Plex `includeRelated` similar/
  director hubs) + Replay + Back; avoid a fake "next".

Plex data to use (all already available): on-deck / next episode, `includeRelated`
similar hubs, watched/progress, `ratingKey`, grandparent/parent metadata, artwork,
duration/`viewOffset`.

**Recommendation:** YES — a dedicated Epic 4 slice to *standardize + verify*
post-play (cross-player, no-surprise-autoplay, related-for-movies), reusing the
existing components. Do **not** migrate to `AVContentProposal` (cross-player
fragmentation).

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
| Content proposals / post-play | **New slice recommended** — *standardize + verify* the existing custom overlay (cross-player, no-surprise-autoplay, related-for-movies via `includeRelated`, watch-state-before-proposal). NOT an `AVContentProposal` rebuild. |
| Native chapter markers | **Already done natively** (§6). No slice (device-verify only). |
| Player GUI conformity | **Already conformant** (§2). No slice (device-verify only). |
| Plex metadata wiring | **Already wired** (§7). No slice. |
| Subtitle/audio UI parity | Stays **E4-PR7** (existing plan). |

Net: the audit confirms most AVKit-reference items are **already implemented
natively**. The one genuinely new candidate is a **post-play UX standardization
slice**; everything else is verify-on-device or existing planned slices.

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
