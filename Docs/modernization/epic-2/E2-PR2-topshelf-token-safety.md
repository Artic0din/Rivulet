# E2-PR2 — Top Shelf Token-Safety and Secure Image Handoff

Date: 2026-06-01

Owner: Epic 2 owner

Gates: E0-G01 (token handling), E0-G02 (network inventory), E0-G03 (privacy),
E0-G08 (observability). Surface: `NET-019`. Debt: `DEBT-E0-002` / `E0-SEC-003`.

## Handoff behavior — before

- `TopShelfItem.imageURL: String` held a **full Plex URL with `X-Plex-Token`**
  ("Full Plex URL with token", model comment).
- `PlexDataStore.updateTopShelfCache()` built that token URL
  (`…?X-Plex-Token=<selected server token>`) and wrote it into the App Group
  payload (`UserDefaults(suiteName: group.com.bain.Rivulet)` key `topShelfItems`).
- `TopShelfExtension/ContentProvider` read the payload and called
  `tvItem.setImageURL(url)` with the token URL → **tvOS fetched a token-bearing
  URL from inside the extension** (the `NET-019` / `E0-SEC-003` leak).
- `TopShelfCache` (both copies) used `print(...)` including the first item's
  title — forbidden by the observability policy.
- Deep link: `rivulet://play?ratingKey=<key>&server=<serverURL>` — already
  token-free (NET-021).

## Handoff behavior — after

- `TopShelfItem.imageURL` removed. New field `imageFileName: String?` — an opaque
  local filename inside the App Group `TopShelfImages/` directory, or `nil`.
- The token-bearing thumb URL is now built **only transiently in-app**
  (`TopShelfDraft.authenticatedThumbURL`), used solely to fetch image bytes via
  `ImageCacheManager.imageData(for:)` (the app's authenticated, SSL-trust-aware
  session), then discarded. It is never persisted, logged, or shared.
- Fetched bytes are written to `TopShelfImages/<ratingKey>.jpg` in the App Group
  container; the payload stores only the filename.
- The extension resolves `imageFileName` → a **local file URL**
  (`TopShelfCache.imageFileURL(forFileName:)`, path-traversal guarded, existence
  checked) and hands that local URL to `setImageURL`. No token, no network fetch
  in the extension.
- `print(...)` removed from both `TopShelfCache` copies; replaced with `Logger`
  emitting counts only (no titles, URLs, or payloads).

## Image handoff design decision

App-fetches-bytes → local App Group file → extension reads local file. Chosen
over alternatives because it fully removes the token from the extension boundary
while reusing the app's existing trust-aware image session (`ImageCacheManager`,
which handles self-signed local Plex certs). Rejected: passing an opaque token
URL (still a secret in disguise — explicitly forbidden), or fetching from the
extension with a short-lived token (still shares a secret + needs trust handling
in the extension).

## App Group payload decision

`TopShelfItem` remains the App Group payload, now secret-free: `ratingKey`,
`title`, `subtitle`, `imageFileName?`, `progress`, `type`, `lastWatched`,
`serverIdentifier`. `imageFileName` is optional so payloads written by older
builds (token-bearing `imageURL`, no `imageFileName`) **decode safely as
imageless** rather than failing — and the unknown `imageURL` key is ignored, so
the stale token is not surfaced and is overwritten on the next refresh.

## Deep-link payload decision

Unchanged and already secret-free: `ratingKey` (non-secret identifier) +
`serverIdentifier`. `serverIdentifier` currently equals the selected server URL
(a LAN address, not a token/credential/stream URL); it is the pre-existing,
accepted deep-link field (NET-021) and is **not** modified here to avoid touching
Epic 1 server-selection / deep-link resolution. No token, stream URL, media URL,
PIN, or credential is present.

## Fallback behavior

If no safe local image exists (fetch failed, no thumb, or file missing), the
extension omits artwork and still displays the item (title + deep link). The
whole payload is never dropped because artwork is unavailable. No URL is logged
on fallback.

## Security / redaction review

- No `X-Plex-Token`, token-bearing URL, stream URL, credential, or PIN in: the
  App Group payload, the extension, extension logs, or deep links. (Scan results
  recorded in the final report.)
- Token appears only in `TopShelfPayloadBuilder.authenticatedThumbURL` (transient
  in-app fetch) and `PlexDataStore` (local `token` constant feeding it) — never
  persisted.
- Observability: `print()` removed from Top Shelf paths; `Logger` (subsystem
  `com.rivulet.app` app / `com.gstudios.rivulet.TopShelfExtension` extension,
  category `TopShelf`/`ContentProvider`) logs counts only. No URL is logged, so
  `SensitiveDataRedactor` is not required on these paths (nothing URL-bearing is
  emitted); the redactor remains the policy for any future URL diagnostics.

## Privacy matrix

No change to disclosed data flows: the same artwork is shown and the same
deep-link identifiers are used. Data now stays more local (image bytes cached in
the App Group instead of a token URL handed to the system image loader). No new
collection/transmission. Privacy matrix update not required.

## Known limitations / residual

- On upgrade from a pre-E2-PR2 build, a stale token-bearing `imageURL` may remain
  in App Group UserDefaults until the first Continue Watching refresh overwrites
  the key. The value is ignored by the new model and replaced promptly; no new
  token is ever written.
- Image fetch reuses `ImageCacheManager`; if a poster is uncached and the server
  is unreachable, the item shows without art (safe fallback).
