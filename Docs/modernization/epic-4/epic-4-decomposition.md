# Epic 4 — Playback Excellence — Decomposition (Planning Only)

Date: 2026-06-01
Status: **Planning only. No implementation authorised.** Companion to
`epic-4-architecture-report.md`.
Owner: Epic 4 owner (Epic 1 owner supports watch-state boundaries).

Epic 0/1/2/3 are closed with accepted debt. Nothing here authorises code; this
is the proposed plan for a future, separately-approved Epic 4.

---

## 1. Objective

Make playback reliable and premium across the validation corpus: a ratified
AVKit-first presentation policy with a deterministic RPlayer capability
fallback; correct resume/session behaviour; robust interruption/failure
recovery; faithful DV/HDR and subtitle/audio handling; and clean, secret-free
playback telemetry — without regressing the unique coverage RPlayer provides.

Parity target: Playback 3 → 5 (capped at 4 until corpus-backed device evidence;
the open Sentry stream-URL leakage blocker must close first).

---

## 2. Scope / non-goals

In scope: routing policy + presentation default, fallback ladder, resume/session
correctness, interruption recovery, telemetry contract, playback security
(stream-URL redaction), and the route decision matrix.

Out of scope / must not change: the Epic 1 watch-state boundary
(`PlexProgressReporter`, `PlexWatchStateRequestFactory`) — consume only; Epic 1
provider/auth/token transport; app rename; project settings / deployment target /
Swift version; Apple branding/private APIs. DV/HDR RPU-rewrite and
`DisplayCriteriaManager` internals stay as-built (only routing around them
changes).

---

## 3. Governing constraints

- Media-corpus-backed device validation is a hard pre-merge gate for any routing
  change (`DEBT-E1-PR1-004`).
- E0-G01/G08: no stream URL, token, or credential in any log/telemetry/Sentry
  sink; `SensitiveDataRedactor` for all playback diagnostics.
- E0-G07 performance budgets (startup, rebuffer) apply; capture required.
- One fallback per failure at current playback time (preserve today's behaviour).
- No third-party analytics.

---

## 4. Proposed PR slices

- **E4-PR1 — Playback security: stream-URL redaction** (gating). Eliminate stream
  URL/token leakage to Sentry/logs (`E0-OBS-002`/`E0-OBS-003`); redactor-first
  diagnostics. Closes the Playback parity blocker. Highest priority.
- **E4-PR2 — Telemetry contract**. `os_signpost`/structured playback telemetry
  (startup, rebuffer, route, fallback reason); no third-party analytics; no URLs.
- **E4-PR3 — Pure routing + fallback policies**. Extract `PlaybackRoutingPolicy`
  (AVKit-first selection) + `PlaybackFallbackPolicy` (deterministic ladder) as
  pure, tested seams; wire behind a flag; keep `useApplePlayer` semantics during
  migration. No default flip yet.
- **E4-PR4 — Resume/session correctness**. Pure `PlaybackResumePolicy` (start
  offset, seek-on-resume dedupe) + per-route verification.
- **E4-PR5 — Interruption/failure recovery**. Deterministic recovery ladder via
  `.failed(PlayerError)`; calm redacted error copy; corpus failure-mode tests.
- **E4-PR6 — AVKit-first default flip (staged)**. Flip default to AVKit-first with
  RPlayer capability fallback, gated/staged; corpus + device validation.
- **E4-PR7 — Subtitle/audio parity verification**. Track-selection parity across
  AVPlayer/RPlayer; documented matrix; lossless audio remains RPlayer/remux.
- **E4-PR8 — Epic 4 closure**. Corpus evidence, parity submission, telemetry
  review, closure report.

Each slice independently reviewable/reversible; pure policies tested; routing
changes flag-gated and corpus-validated before merge.

---

## 5. Route decision matrix

See `epic-4-architecture-report.md` §3 (the canonical proposed matrix).

---

## 6. Risk register

See `epic-4-architecture-report.md` §5.

---

## 7. Acceptance criteria (exit gate)

1. AVKit-first policy ratified and implemented with deterministic RPlayer
   fallback; route matrix validated against the corpus.
2. Resume/session correct across all routes (UAT + tests).
3. Interruption/failure recovery deterministic; calm secret-free errors.
4. DV/HDR + subtitle/audio faithful across routes (device-validated).
5. Telemetry contract clean (no URLs/tokens; no third-party analytics).
6. Stream-URL leakage blocker (`E0-OBS-002/003`) closed.
7. Performance budgets met or accepted as dated debt; corpus device runs.
8. Watch-state boundary unchanged (Epic 1 consume-only).
9. Evidence linked; parity Playback submission with corpus evidence.
10. Epic 4 closure report with accepted-debt list.

---

## 8. Stop/go recommendation

**GO to detailed planning; HOLD implementation** until: (a) Project Owner
ratifies AVKit-first-as-default (architecture report §6 Q1); (b) media corpus +
physical Apple TV are available for the mandatory device gate; (c) E4-PR1
(stream-URL redaction) is scheduled first. Epic 4 can then begin with E4-PR1.

No Epic 4 code has been written. This document is planning only.

---

## 9. Addendum — Apple AVKit reference audit (2026-06-02)

See `apple-avkit-playback-reference-audit.md`. Public-API/HIG mapping confirmed
several roadmap items are **already implemented natively**, and surfaced one
net-new slice:

- **Already native (no new slice; device-verify only):** external metadata via
  `AVPlayerItem.externalMetadata` (title/subtitle/desc/genre/rating/year/artwork,
  token-safe); native chapters via `AVPlayerItem.navigationMarkerGroups`
  (`includeChapters=1`); native transport / Siri Remote / Now Playing / PiP on the
  `AVPlayerViewController` path; contextual Skip via `contextualActions`.
- **New slice — E4-PR9 (Post-play UX standardization):** standardize + verify the
  existing custom post-play overlay (`Views/Player/PostVideo/`) against Apple's
  content-proposal *model* — cross-player (RPlayer + AVKit), artwork/title/Play-
  Next/Back, **no surprise autoplay** (countdown cancellable/setting-gated),
  related-for-movies via Plex `includeRelated`, watch-state updated before the
  proposal (Epic 1 consume-only). **Do NOT** migrate to `AVContentProposal`
  (AVKit-path only → cross-player fragmentation). No corpus/device dependency for
  the logic; on-device UX verification before close. Tracked `DEBT-E4-AVKIT-001`.
- **Backlog (optional, minor):** AVKit metadata enrichment (precise release date,
  dedicated season/episode identifiers); Plex `includeRelated` adoption for
  post-play related rows. Tracked `DEBT-E4-AVKIT-001`.

Recommended order unchanged: E4-PR5 (recovery) next; E4-PR9 (post-play) after
E4-PR5 / alongside E4-PR7; E4-PR6 flip remains corpus/device-gated.
