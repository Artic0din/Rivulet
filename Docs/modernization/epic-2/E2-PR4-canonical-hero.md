# E2-PR4 — Canonical Hero and Hero-First Home

Date: 2026-06-01

Owner: Epic 2 owner

Gates: E0-G04 (A11Y-001, A11Y-003), E0-G07 (PERF-001/002/003/009). Parity:
Home and Hero categories.

First user-visible Apple-TV-parity PR. Scope: the Home Hero only.

## Hero behavior — before

- The hero existed but was **off by default**: `@AppStorage("showHomeHero") = false`.
  Home was row-first; the hero only appeared if a user manually enabled it.
- `contentView` already rendered `HeroBackdropLayer` + `HeroOverlayContent`
  above the rows when `heroActive == (showHomeHero && !heroItems.isEmpty)`, with
  parallax backdrop, paging dots, and focus-driven scroll — but this premium
  surface was dormant.
- Hero selection (`computeHubBackedHero`) prioritised curated → recently added →
  first non-empty hub and **did not lead with Continue Watching**.
- Selection logic was inline and untested; initial hero focus was whatever the
  focus engine picked; slide crossfade / paging-dot animation ignored Reduce
  Motion.

## Hero behavior — after

- **Hero is the canonical, default Home experience**: `showHomeHero = true`
  (still a user-overridable preference; only the default flips). Launch lands
  hero-first: Hero → rows.
- Selection is governed by a pure, tested `HeroSelectionPolicy`.
- Deterministic initial focus on the hero **Play** action via `.defaultFocus`.
- Slide crossfade and paging-dot animation honour Reduce Motion.

## Hero selection rules (deterministic)

`HeroSelectionPolicy.select(from:cap:)` — pure, priority order:

1. **Continue Watching** (active resume content)
2. **Curated / featured** (`recommended`, `promoted`, `featured`, `spotlight` hubs)
3. **Recently Added**
4. **Any other** non-empty hub (first, stable order)

Rules:
- Items without a `ratingKey` are dropped; if a higher-priority kind has no
  identity-bearing items, selection falls through to the next.
- Result capped at `heroItemCap` (9).
- **Never empty when usable content exists** — falls back to the first candidate
  with identity-bearing items. Returns `[]` only when no content exists, which
  the Home `RenderState` empty state then handles.
- `PlexHomeView.computeHubBackedHero` maps `[PlexHub]` → `[HeroHubCandidate]`
  (preserving hub order) and delegates to the policy. The async
  `upgradeHeroFromTMDB` enhancement (popular library matches = featured tier)
  is unchanged and continues to refine the set after the immediate pick.

## RenderState participation (E2-PR1)

- The hero renders only inside `contentView`, which is shown only in the
  `RenderState` `.content` phase (via `ContentStateView`). Loading / empty /
  error phases are owned by `ContentStateView`, not the hero.
- When hubs exist but yield no hero item, `heroActive` is false and Home falls
  back to rows-only — no empty hero. The selection policy guarantees a hero
  whenever any hub has identity-bearing content.

## Hero focus behavior (E2-PR3)

- **Deterministic initial focus:** `.defaultFocus($focusedButton, .play)` on the
  hero overlay — Play is the preferred entry target; it is always present, so
  focus is never stranded.
- **Hero → first row:** down-navigation leaves the hero `.focusSection()` into
  the rows; `onRowFocused` centres the focused row (existing behaviour).
- **Sidebar → hero:** entering content focuses the hero (Play) via defaultFocus;
  `onHeroFocused` scrolls the hero to top (existing behaviour).
- **Return Home:** `heroItems` / `heroCurrentIndex` persist in view state and the
  hero cache; Play remains the deterministic focus target. No custom focus
  engine added; relies on tvOS focus + `focusSection` + defaultFocus.

## Accessibility findings (A11Y-001, A11Y-003)

- Hero action buttons carry VoiceOver labels (Play text; "Add/Remove from
  Watchlist", "More info", "Next featured item"). Title/metadata are text
  (`HeroSlideContent`) and natively accessible.
- Deterministic, predictable focus order (Play first).
- **Reduced Motion:** slide crossfade swaps instantly and paging-dot animation
  is disabled when Reduce Motion is on. Scroll-follow on focus remains (direct
  navigation response).
- On-device VoiceOver/focus validation on physical Apple TV remains required
  before Epic 5 (`DEBT-E0-007`). Not performed in this PR.

## Performance findings (PERF-001/002/003/009)

- Hero preparation is instrumented (E2-PR1 `beginHeroPreparation` /
  `endHeroPreparation`, PERF-003) and unchanged by this PR.
- The default flip surfaces the existing hero render path; no new blocking
  network calls or focus-time work were added. Selection is pure in-memory hub
  mapping. Artwork uses the existing cached image path (no new image loading on
  focus).
- Numeric PERF-001/002/003/009 median/p95 capture remains outstanding
  (`DEBT-E0-008`); the harness is in place to capture it.

## Tests

- `HeroSelectionPolicyTests` (11): CW-first priority, curated/recently-added/
  other fall-through, identity filtering + fall-through, cap, empty cases,
  priority-order constant.

## Residual / unresolved

- On-device A11Y + numeric performance capture outstanding (`DEBT-E0-007`,
  `DEBT-E0-008`).
- Existing users who previously toggled `showHomeHero` off keep their stored
  preference; only the default changes (documented, intended).
- `upgradeHeroFromTMDB` retains a token-bearing poster URL construction for the
  watchlist toggle path (pre-existing, Epic 1/3 watchlist surface — `NET-026`);
  out of scope for E2-PR4 and untouched.
