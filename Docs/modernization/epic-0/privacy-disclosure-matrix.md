# Privacy Disclosure Matrix

## Purpose

This matrix records the user, device, Plex, server, extension, and diagnostic data touched by Rivulet. It is the baseline for Epic 1 PR 3: Privacy Manifest and Plex Data Disclosure Baseline.

The matrix does not redesign Plex integration, move token transport, change endpoint behavior, alter auth flow behavior, or change playback behavior. It makes the current privacy surface reviewable before later Epic 1 implementation PRs.

## Review Rules

1. Any new data item must be added before merge.
2. Any change to storage, retention, sharing, or telemetry sinks requires Project Owner or delegated privacy reviewer approval.
3. Any item involving credentials, token-bearing URLs, Sentry, Top Shelf, deep links, NSUserActivity, local network access, or Plex Home identity requires security/privacy review.
4. Privacy manifest updates do not close token-transport, ATS, Sentry ownership, or Top Shelf runtime handoff debt unless the matching debt close condition is satisfied.

## Privacy Manifest Baseline

| Target or dependency | Manifest decision | Target or project membership | Evidence ID | Notes |
| --- | --- | --- | --- | --- |
| Main app target `Rivulet` | Manifest required and added at `Rivulet/PrivacyInfo.xcprivacy` | Included through the `Rivulet` `PBXFileSystemSynchronizedRootGroup`; no manual project-file membership edit is required unless Xcode build validation proves otherwise | E1-PR3-PRIV-001 | Declares no tracking, no tracking domains, `UserDefaults` required-reason access, file metadata access for cache sizing, Plex/app-functionality data, search history, and diagnostics |
| Top Shelf extension target `TopShelfExtension` | Manifest required and added at `TopShelfExtension/PrivacyInfo.xcprivacy` | Included through the `TopShelfExtension` `PBXFileSystemSynchronizedRootGroup`; no manual project-file membership edit is required unless Xcode build validation proves otherwise | E1-PR3-PRIV-001 | Declares no tracking, no tracking domains, App Group `UserDefaults` required-reason access, Top Shelf identity, interaction, and payload data |
| `sentry-cocoa` SwiftPM package | No repo-authored manifest added in PR 3 | External SwiftPM dependency pinned in `Rivulet.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`; upstream package privacy contents are dependency-owned | E1-PR3-SENTRY-001 | Rivulet still owns data it attaches to Sentry events and must confirm Release DSN ownership before release validation |
| Embedded FFmpeg and libdovi xcframeworks | No target-specific manifest added in PR 3 | Repository binary frameworks are embedded playback dependencies, not standalone app or extension targets | E1-PR3-PRIV-001 | If App Store validation later flags an SDK manifest requirement, the issue must be tracked as release-readiness debt without changing Epic 1 scope |

## Required-Reason API Baseline

| API category | Current repo use | Declared reason | Evidence ID | Notes |
| --- | --- | --- | --- | --- |
| `NSPrivacyAccessedAPICategoryUserDefaults` | Standard app preferences, selected server metadata, library settings, playback preferences, recent searches, and App Group Top Shelf cache | `CA92.1` for app-only defaults and `1C8F.1` for App Group or shared defaults | E1-PR3-SCAN-001 | Tokens are intended to live in Keychain; legacy token migration remains token-hygiene debt and is not expanded in PR 3 |
| `NSPrivacyAccessedAPICategoryFileTimestamp` | App-container cache sizing through `URLResourceValues.fileSizeKey` in cache managers | `C617.1` | E1-PR3-SCAN-001 | Used for cache management within the app container, not fingerprinting or tracking |
| Disk-space APIs | No matching scan result in PR 3 | Not declared | E1-PR3-SCAN-001 | Revisit if future cache work calls file-system capacity APIs |
| System boot-time APIs | No matching scan result in PR 3 | Not declared | E1-PR3-SCAN-001 | Revisit if future performance instrumentation uses boot-time APIs |
| Active keyboard APIs | No matching scan result in PR 3 | Not declared | E1-PR3-SCAN-001 | Not applicable to current tvOS surfaces |

## Disclosure Matrix

| Data item | Source | Purpose | Storage location | Retention assumption | Sharing or sink | Leaves device | User-linked | Sensitive | Privacy manifest impact | App Store privacy disclosure impact | Owner | Evidence ID | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Plex account token | Plex PIN auth and account auth flow | Authenticate account-level plex.tv, resources, Plex Home, Discover, and watchlist calls | Keychain; legacy UserDefaults migration path exists | Until logout, uninstall/keychain lifecycle, or credential replacement | plex.tv and Discover/provider APIs; app runtime | Yes | Yes | Yes | Covered by `UserID` and `OtherData`; no tracking | Credentials/authentication data; not used for tracking; no raw logging permitted | Epic 1 owner | E1-PR3-MATRIX-001 | Token transport migration remains deferred to later Epic 1 PRs |
| Plex server token | Selected Plex server and shared-server access | Authenticate PMS browse, playback, state, timeline, image, and subtitle calls | Keychain; in-memory runtime | Until logout, server reselection, or credential replacement | Selected PMS and PMS-owned relay paths | Yes | Yes | Yes | Covered by `UserID` and `OtherData`; no tracking | Authentication and app functionality data; token-bearing URLs remain debt | Epic 1 owner | E1-PR3-MATRIX-001 | Query-token construction remains tracked under `DEBT-E0-002` and `DEBT-E1-PR1-001` |
| Plex Home user token | Plex Home switch response | Scope PMS access to selected Home user | Keychain or credential registry runtime depending on current flow | Until user switch, logout, or credential replacement | Selected PMS and plex.tv Home APIs | Yes | Yes | Yes | Covered by `UserID` and `OtherData`; no tracking | Account/profile data used for app functionality | Epic 1 owner | E1-PR3-MATRIX-001 | Home-user lifecycle remains Epic 1 implementation work |
| Plex Home PIN | Plex Home protected-user switch flow | Authorize profile switch | Keychain or transient auth request depending on flow | Until switch request completes or saved credential is removed | plex.tv Home switch endpoint when required | Yes | Yes | Yes | Covered by `OtherData`; no tracking | Sensitive credential-like data used only for app functionality | Epic 1 owner | E1-PR3-MATRIX-001 | PINs must never appear in logs, Sentry, deep links, or Top Shelf payloads |
| Plex account identifier | `/api/v2/user`, account metadata, auth state | Display account context and bind resources | Runtime and app state; may influence UserDefaults preferences | Until logout or refresh | plex.tv; possibly Sentry only if explicitly attached by future code | Yes | Yes | Medium | Covered by `UserID`; no tracking | User ID/account data for app functionality | Epic 1 owner | E1-PR3-MATRIX-001 | Do not add to Sentry user context without privacy review |
| Plex server identifier | Plex resources, Top Shelf payload, deep-link action URL | Select correct server for playback, Top Shelf, and deep links | UserDefaults, SwiftData server records, App Group Top Shelf cache, runtime | Until server removal, logout, cache expiry, or overwrite | PMS, app extension, deep-link handler | Yes for PMS; local extension handoff stays on device | Yes | Medium | Covered by `UserID` and `OtherData`; extension manifest covers Top Shelf handoff | Server identifier and app functionality data | Epic 1 owner and Epic 2 owner | E1-PR3-MATRIX-001 | Top Shelf deep link includes `server` query item and remains minimization debt |
| Plex server URL and connection URI | Server discovery, selected server persistence, manual or resource-provided connections | Connect to selected PMS over LAN, relay, or remote URL | UserDefaults, SwiftData `PlexServer`, runtime request builders | Until server reselection, logout, or cache cleanup | Selected PMS; Sentry only as redacted host/context after PR 2 | Yes | Yes | Medium | Covered by `OtherData`; no tracking | Local network and server connection data for app functionality | Epic 1 owner | E1-PR3-LOCAL-001 | Raw server URLs must stay out of logs/Sentry unless redacted |
| Local network access | Plex local server discovery and direct PMS connections | Discover and connect to local Plex Media Server and local TV devices | Info.plist network policy and runtime URL requests | Runtime plus selected server persistence | Local PMS, HDHomeRun, LAN services | Yes, to local network | Yes | Medium | Covered by `OtherData`; no tracking | Local network data and diagnostics disclosure required | Epic 1 owner | E1-PR3-LOCAL-001 | `NSLocalNetworkUsageDescription` and Bonjour declarations are absent; tracked as PR 3 debt |
| Server discovery results | plex.tv resources, local connection probes, legacy PMS fallback | List and select PMS instances | Runtime; selected server metadata persisted | Discovery results are refreshed; selected server persists | plex.tv, local PMS, UserDefaults/SwiftData | Yes | Yes | Medium | Covered by `OtherData`; no tracking | App functionality and local network disclosure | Epic 1 owner | E1-PR3-LOCAL-001 | Legacy fallback containment remains open under ADR-003 |
| Selected server persistence | User selection after auth/resource discovery | Restore preferred PMS and library context | UserDefaults and SwiftData server records | Until logout, uninstall/UserDefaults reset, or server reselection | Local app storage; may be used in Top Shelf cache generation | No direct external sink | Yes | Medium | Covered by `OtherData`; no tracking | App functionality data stored on device | Epic 1 owner | E1-PR3-MATRIX-001 | Sensitive token is intended to stay in Keychain, not SwiftData |
| Plex Home profile identity | Plex Home users and selected profile state | Display/select correct profile and scope access | Runtime, UserDefaults selected profile state, Keychain for token/PIN where applicable | Until profile switch, logout, or credential cleanup | plex.tv Home API and selected PMS | Yes | Yes | Medium | Covered by `UserID` and `OtherData`; no tracking | Account/profile data for app functionality | Epic 1 owner | E1-PR3-MATRIX-001 | Profile image URLs may be sensitive if PMS-hosted |
| Watch progress and timeline state | Playback view model, PMS timeline reporting, Continue Watching | Resume playback and synchronize progress | Runtime, SwiftData or cache models, PMS state | Until PMS overwrites, user marks watched/unwatched, cache eviction, or logout | PMS timeline endpoints and Top Shelf cache | Yes | Yes | Medium | Covered by `ProductInteraction`; extension manifest covers Continue Watching payload | Product interaction and app functionality data | Epic 1 owner and Epic 4 owner | E1-PR3-MATRIX-001 | Timeline ownership remains Epic 1/Epic 4 boundary work |
| Watched and unwatched state | PMS state writes and local UI state | Display watched status and allow scrobble/unscrobble | Runtime, PMS server state, local UI state | Until user changes state or PMS refreshes | PMS state endpoints | Yes | Yes | Medium | Covered by `ProductInteraction`; no tracking | Product interaction data for app functionality | Epic 1 owner and Epic 4 owner | E1-PR3-MATRIX-001 | State-write adapter ownership remains open |
| Search queries | Plex search views, Siri/AppIntents search entity query, Discover search | Return media results and Siri/AppIntents results | Runtime; `@AppStorage("recentSearches")` stores recent search data | Recent searches persist until cleared or overwritten; network query runtime only | PMS search and possibly Siri/AppIntents result rendering | Yes | Yes | Medium | Covered by `SearchHistory`; no tracking | Search history and app functionality disclosure | Epic 1 owner and Epic 2 owner | E1-PR3-MATRIX-001 | Raw search query logging is not approved |
| Watchlist and Discover actions | `PlexWatchlistAPI`, Discover/provider hosts | Fetch, add, and remove watchlist items | Runtime and Discover cache | Cached Discover data until cache expiry or overwrite | `discover.provider.plex.tv`, `metadata.provider.plex.tv`, public artwork CDNs | Yes | Yes | Medium | Covered by `ProductInteraction`, `OtherData`, and `SearchHistory` where query-like | Product interaction and third-party/provider sharing disclosure | Epic 1 owner | E1-PR3-MATRIX-001 | Provider endpoints remain unstable and query-token scoped |
| Sentry crash data | Non-Debug Sentry SDK startup when DSN configured | Diagnose crashes and severe runtime errors | Sentry backend when Release DSN exists | Sentry project retention policy; not controlled in repo | Sentry | Yes when enabled | Not intentionally linked after PR 2 sanitization | Medium to High | Covered by `CrashData`; no tracking | Crash data disclosure required if Release Sentry enabled | Project Owner and Epic 1 owner | E1-PR3-SENTRY-001 | Release DSN ownership must be confirmed or reporting disabled before release validation |
| Sentry breadcrumbs | Sentry SDK and app-supplied breadcrumbs after PR 2 redaction | Diagnose failure path | Sentry backend when Release DSN exists | Sentry project retention policy | Sentry | Yes when enabled | Not intentionally linked after PR 2 sanitization | Medium | Covered by `OtherDiagnosticData`; no tracking | Diagnostics disclosure required if Release Sentry enabled | Project Owner and Epic 1 owner | E1-PR3-SENTRY-001 | Automatic network breadcrumbs are disabled by PR 2 |
| App diagnostics | Logs, print statements, Sentry extras, allowed diagnostic context | Debug and investigate behavior | Local console, Sentry if explicitly captured in Release | Local logs ephemeral; Sentry follows project retention | Local console and Sentry if configured | Maybe | Maybe | Medium | Covered by `OtherDiagnosticData` and `PerformanceData`; no tracking | Diagnostics disclosure required | Epic 1 owner and Epic 4 owner | E1-PR3-SENTRY-001 | Broad print modernization remains open debt |
| Deep-link payloads | `rivulet://play` and `rivulet://detail` URLs | Open detail or playback from Top Shelf, Siri, and app activity | Runtime URL payload; Top Shelf action URL | Runtime; Top Shelf action exists while cache is active | tvOS URL dispatch and app handler | No external server sink by itself | Yes | Medium | Covered by `UserID` and `OtherData`; no tracking | App functionality data; media identifier disclosure | Epic 2 owner | E1-PR3-DEEPLINK-001 | Current payloads carry `ratingKey`; Top Shelf also adds server identifier |
| NSUserActivity payloads | Media detail and playback views | Siri/search indexing and handoff into detail/play actions | System `NSUserActivity` runtime index | System-managed until activity is resigned or replaced | tvOS system search/Siri surfaces | Leaves app boundary to OS services | Yes | Medium | Covered by `UserID` and `OtherData`; no tracking | Search/Siri app functionality data disclosure | Epic 2 owner | E1-PR3-DEEPLINK-001 | Current activity uses `ratingKey` and title, not tokens |
| Top Shelf cache payloads | Main app `TopShelfCache.writeItems` | Populate Continue Watching Top Shelf | App Group `UserDefaults` encoded JSON | Until overwritten or cleared | Top Shelf extension | No network by itself, but extension consumes image URLs | Yes | High when image URL is token-bearing | Covered by extension `UserID`, `ProductInteraction`, and `OtherData`; no tracking | App functionality data and extension payload disclosure | Epic 2 owner | E1-PR3-TOPSHELF-001 | Payload includes rating key, title, subtitle, image URL, progress, type, last watched date, and server identifier |
| Top Shelf image URLs | PMS image URL in Top Shelf item payload | Display artwork on Top Shelf | App Group `UserDefaults`; TVTopShelf image URL assignment | Until Top Shelf cache overwrite or clear | TV Services extension and PMS image host | Yes when image loads | Yes | High if token-bearing | Covered by extension `OtherData`; no tracking | Image/metadata payload disclosure; token-bearing handoff remains debt | Epic 2 owner | E1-PR3-TOPSHELF-001 | Runtime token-bearing image URL handoff is not fixed in PR 3 |
| Media metadata | PMS browse/detail/search responses, Discover metadata, Siri/AppIntents entities | Render content, search, detail, Top Shelf, playback, and recommendations | Runtime, SwiftData/cache managers, Top Shelf payload subset, NSUserActivity title | Until cache expiry/overwrite, logout, or OS activity replacement | PMS, Discover/provider, public CDNs, OS search surfaces, Top Shelf extension | Yes | Yes | Medium | Covered by `OtherData`, `ProductInteraction`, and `SearchHistory`; no tracking | Content metadata and app functionality disclosure | Epic 1 owner and Epic 3 owner | E1-PR3-MATRIX-001 | Media titles may be sensitive if attached to diagnostics; PR 2 redaction reduces URL exposure only |
| Artwork and cache metadata | PMS images, public CDNs, image cache, depth-layer cache | Display posters, backdrops, logos, profile images, and generated depth assets | Memory cache, disk cache, App Group Top Shelf cache for Top Shelf item URLs | Until cache eviction, clear, or overwrite | PMS, public CDNs, extension, local cache | Yes when fetched; local when cached | Yes if token-bearing or media-linked | Medium to High | Covered by `OtherData`; file metadata API reason declared for cache sizing | Artwork/media metadata disclosure | Epic 2 owner and Epic 3 owner | E1-PR3-MATRIX-001 | Token-bearing PMS artwork URLs remain token hygiene debt |
| Playback route diagnostics | Player routing, HLS/local remux/direct play, Sentry error context | Diagnose playback route failures | Runtime and Sentry when Release DSN configured | Runtime only or Sentry retention if captured | Sentry when configured; local logs | Maybe | Maybe | Medium to High if raw URLs included | Covered by `OtherDiagnosticData` and `PerformanceData`; no tracking | Diagnostics and performance disclosure | Epic 4 owner | E1-PR3-SENTRY-001 | PR 2 redacts raw stream URL diagnostics; playback behavior is unchanged |
| PMS playback URLs and transcode URLs | Content router, PMS playback endpoint builders, HLS fallback | Start media playback and transcode sessions | Runtime stream URL cache and player state | Runtime/cache lifetime only unless logged | PMS, local remux server, AVPlayer/RPlayer | Yes | Yes | High | Covered by `OtherData` and `ProductInteraction`; no tracking | App functionality and playback data disclosure | Epic 4 owner | E1-PR3-MATRIX-001 | Query-token migration is deferred; raw diagnostic emission remains forbidden |
| Live TV local device URLs | HDHomeRun and PMS Live TV providers | Play local or PMS-managed Live TV | Runtime and local source configuration | Until source removal or stream ends | Local TV device or PMS | Yes, often local network | Yes | Medium | Covered by `OtherData`; no tracking | Local network and app functionality disclosure | Epic 4 owner | E1-PR3-LOCAL-001 | Live TV remains outside PR 3 implementation scope |
| Third-party metadata proxy request data | TMDB proxy and public artwork hosts | Resolve Discover metadata/artwork | Runtime and UI caches | Cache lifetime or runtime only | TMDB proxy, public artwork CDNs | Yes | Maybe | Medium | Covered by `OtherData`; no tracking | Third-party metadata sharing disclosure | Epic 3 owner | E1-PR3-MATRIX-001 | TMDB proxy authentication policy remains future Epic 3/Epic 5 concern |

## Sentry Privacy Decision

As of Epic 1 PR 3:

- Sentry remains disabled in Debug by compile-time guard.
- Sentry can be enabled in non-Debug builds only when ignored local configuration provides `Secrets.sentryDSN`.
- The tracked template uses `YOUR_SENTRY_DSN_HERE` and no real DSN is committed.
- A copied Release DSN could report to an inherited project.
- Current state is acceptable for PR 3 only as a baseline because PR 2 disabled automatic network capture and added event sanitization.
- Epic 1 or release validation may not treat Sentry as production-acceptable until Project Owner confirms Sentry project ownership or disables Release reporting.

## Local Network and ATS Privacy Decision

Rivulet currently needs local network access to reach local Plex Media Server and Live TV devices. The privacy baseline records that:

- `Rivulet/Info.plist` contains `NSAllowsLocalNetworking = true`.
- `Rivulet/Info.plist` contains app-wide `NSAllowsArbitraryLoads = true`, which remains ATS implementation debt.
- No `NSLocalNetworkUsageDescription` or `NSBonjourServices` key is present in the current Info.plist scan.
- Custom trust handlers remain in Plex auth/network/image paths and are governed by ADR-004.
- PR 3 does not scope ATS exceptions, change trust behavior, or alter local-network runtime behavior.

## Deep Link, NSUserActivity, and Top Shelf Privacy Decision

Current payloads are allowed only as a baseline with tracked debt:

- Deep links carry `ratingKey`; Top Shelf action URLs also carry a server identifier.
- NSUserActivity carries `ratingKey`, title, and target content identifier for detail/play flows.
- Top Shelf cache carries media identifier, title/subtitle, watch progress, last watched date, type, server identifier, and a full image URL.
- Top Shelf image URLs can be token-bearing. PR 3 documents this; it does not redesign Top Shelf or replace the runtime handoff.

## Acceptance Criteria

This matrix is acceptable when:

1. Every Epic 1 PR 3 required privacy surface is listed.
2. Every row has source, purpose, storage, retention, sink, device egress, user-linkage, sensitivity, manifest impact, App Store disclosure impact, owner, evidence ID, and notes.
3. Current privacy manifest decisions are explicit for app, extension, Sentry, and embedded framework surfaces.
4. Sentry, Top Shelf, ATS, local-network, and token-transport concerns are either closed by evidence or carried as named debt.

## Escalation

- Missing row for a new data item: merge blocked.
- New or changed data sharing without matrix update: merge blocked.
- Real Sentry DSN, Plex token, PIN, password, or credential committed to git: merge blocked.
- Unreviewed privacy manifest change: merge blocked.
- Release build with unowned Sentry DSN: release gate blocked.
