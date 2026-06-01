# Poster-to-Landscape Design Audit

Date: 2026-06-01
Type: Audit only — no code changed, nothing implemented. Read-only inspection of
the live `.posterExpandsToLandscape` row + geometry analysis + simulator
screenshot review.
Trigger: The prior *Landscape Artwork Availability Report* recommended abandoning
poster→landscape-on-focus in favour of "landscape at rest, landscape on focus."
That recommendation solves the visual defect by **removing the interaction**, not
by fixing it. This audit re-opens the question: how should poster→landscape be
implemented *correctly*, and is there a genuine engineering/product reason to drop
it — or was that a silent scope reduction?

## TL;DR

The black gutters are a **geometry defect, not proof the interaction is wrong**.
The resting card is locked to a **landscape-aspect footprint (392×280)** while it
displays a **portrait poster** — a 2:3 poster `.fit` into a 1.4:1 box leaves
~103 px of black on each side. The *artwork choice* at rest (poster) is correct
for the intended interaction; the *frame aspect* is wrong. Abandoning
poster→landscape "fixes" a frame-aspect bug by deleting a product behaviour — a
half-fix dressed as a solution. The correct production answer is **Approach A done
properly**: a poster-shaped resting cell that expands into a landscape
presentation **as an overlay that overflows above its neighbours** (no row
reflow), reusing Rivulet's existing focus/preview overlay architecture rather than
morphing the in-row cell. This is more work than Approach B and that is the point
— it preserves the intended experience without the gutters.

---

## 1. Current implementation

### Components in play

| Concern | Where | Behaviour |
| --- | --- | --- |
| Card visual | `LandscapeContentCard` | Presentation-only `View` (no Button). `ZStack { landscapeLayer.opacity(showsLandscape ? 1:0); posterRestingLayer.opacity(showsLandscape ? 0:1) }`, both layers locked to the **same fixed `width×height`** frame. |
| Footprint | `ScaledDimensions.continueWatchingWidth/Height` | **392 × 280** in *every* state — resting and focused are the same frame; only the contents cross-fade. |
| Style decision | `ContentPresentationPolicy.showsLandscapeComposition(style:isFocused:)` | `.posterExpandsToLandscape` → `isFocused`. So resting shows `posterRestingLayer`, focused shows `landscapeLayer`. |
| Style degrade | `ContentPresentationPolicy.resolveStyle(preferred:hasLandscapeArtwork:)` | falls back to `.poster` when `art` is absent (good — no empty landscape frame). |
| Artwork map | `PlexContentCardMapper` | landscape = `item.art`; poster = `item.thumb` (`grandparentThumb` for episodes); logo = `clearLogoPath`. Token-safe. |
| Row host | `PlexHomeView.InfiniteContentRow` | `ScrollView(.horizontal) { LazyHStack(spacing: rowItemSpacing=40) { ForEach … Button { … } label: { LandscapeContentCard(…) } } }`. The **Button** owns selection/preview/focus/context-menu; the card is just its visual label. `.scrollClipDisabled()` lets the focus scale-shadow overflow. |
| Focus | `@FocusState focusedItemId` on the row; passed into the card as `isFocused`. Restoration via `FocusRestorationPolicy` on refresh; preview-return via `restorePreviewFocusTarget`. |
| Virtualization | `LazyHStack` — offscreen cells are not laid out. |
| Reduce Motion | `PreviewMotionPolicy.animation(…, reduceMotion:)` → cross-fade/scale is instant when reduced; destination state preserved. |

### The resting layer (the gutter source)

```
posterRestingLayer:
  ZStack { Color(white:0.10); CachedAsyncImage(posterURL).aspectRatio(.fit) }
    .frame(width: 392, height: 280)   // landscape frame
```

A portrait poster `.fit` into a landscape frame is centred with empty sides — the
gutters are *exactly* what this asks for, on a `Color(white:0.10)` fill.

## 2. Why the screenshot looks wrong

There are **two** distinct issues; only the first is the visible defect.

### 2a. Card geometry is incorrect (the actual bug)

- Poster aspect ≈ **0.667** (260×390). Landscape frame aspect = **1.40**
  (392×280).
- Poster `.fit` into 392×280 fits to height (280) → rendered width
  = 280 × (260/390) ≈ **187 px**. The frame is 392 px wide.
- Empty per side = (392 − 187) / 2 ≈ **103 px of black gutter, each side.**
- This is **content-independent**: even items that *have* landscape `art` show the
  gutters at rest, because the resting layer deliberately renders the poster, and
  the poster is portrait inside a landscape box.

**Root cause:** the "constant footprint to avoid row reflow" decision was
implemented as *one landscape-shaped frame for both states*. To avoid reflow we
froze the wrong aspect. A poster at rest must sit in a **poster-shaped** frame.

### 2b. Artwork choice at rest is *correct for the intent*

Showing the poster at rest is the **right** choice for a poster→landscape
interaction — the whole point is poster-first. The mistake is not "poster at
rest"; it's "poster inside a landscape frame." So:

- Geometry: **incorrect** (landscape frame holding a portrait image).
- Artwork: **correct** for poster→landscape (poster rest, landscape focus); it
  would only be "wrong" if we abandon the interaction.
- Verdict: **geometry is the defect, not the artwork policy.** The focused state
  (full-bleed `art`, e.g. "The DRAMA") is correct and proves the landscape half
  works.

### 2c. Why the resting state *feels* wrong (beyond the gutters)

The row sits directly under the Continue Watching row, which is full-bleed
landscape. A row of portrait posters floating in wide black landscape boxes reads
as broken alignment — two different shapes pretending to share a frame. A *clean*
poster row (poster-shaped cells, no boxes) would not feel wrong; the boxed-poster
hybrid does.

## 3. Interaction goals (what poster→landscape must deliver)

1. **Poster-first at rest.** Dense, scannable, portrait — the catalogue look.
2. **Landscape reveal on focus** — backdrop `art` + logo + Rating·Year·Runtime,
   the cinematic "this one" treatment.
3. **No black gutters in any state.** Resting poster fills a poster-shaped cell;
   focused landscape fills a landscape-shaped surface.
4. **No row reflow / clip / overlap.** Horizontal neighbours must not shift when a
   card expands; the expansion must not be clipped by the scroll view.
5. **Stable accessibility identity.** One combined VoiceOver label, unchanged
   across rest↔focus (already satisfied by `ContentCardAccessibility.label`).
6. **Reduce-Motion safe.** Instant swap, destination preserved (already satisfied
   by `PreviewMotionPolicy`).
7. **No focus-time network.** Both artworks resolved up front (already satisfied —
   URLs are passed in).

The current implementation meets 5–7 but fails 3 (gutters) and conflates 1 and 4
(it froze a landscape frame to satisfy 4, which broke 1/3).

## 4. Interaction-pattern analysis (not product copying)

Three industry patterns, analysed structurally:

- **Portrait-rest → in-place landscape expand.** A poster-shaped cell, on focus,
  grows and changes aspect into a landscape panel drawn **above** its neighbours
  (the row reserves vertical headroom; horizontal slots stay poster-width so
  siblings don't move). The expanded panel adds backdrop + logo + metadata. The
  expansion is an **overlay over a stable grid**, not a reflow of the grid.
- **Landscape-rest → scale-only focus.** Every cell is landscape at rest; focus
  just scales ~1.05 and lifts a shadow. Trivial geometry, no aspect morph. This is
  what Rivulet's Continue Watching row already does, and what the prior report
  proposed for *all* rows.
- **Portrait-rest → delayed inline landscape preview.** Poster at rest; on focus
  it first scales as a poster, then after a short dwell cross-fades to a landscape
  preview (sometimes autoplaying). Richest, but adds a timed two-phase reveal and
  a dwell-timer state machine.

The common, transferable principle: **the resting cell's shape must match its
artwork**, and **aspect-changing expansion must happen in an overlay layer so the
underlying grid never reflows.** That principle — not any one product — is the bar.

## 5. Approach comparison

### Approach A — Poster at rest → landscape on focus *(the intended experience, done correctly)*

Resting cell is **poster-shaped (260×390)** with the poster `.fill` (no gutters).
On focus, the card renders the **landscape composition (≈392×280) as an overlay**
that overflows above/around its slot (drawn with raised `zIndex`, clipping
disabled), while the slot's reserved horizontal width stays poster-width so
neighbours don't move. The row reserves vertical headroom for the taller of the
two presentations.

| Dimension | Assessment |
| --- | --- |
| Visual quality | **Highest** — true poster catalogue + cinematic focus reveal; no gutters; matches goals 1–3. |
| Engineering complexity | **High** — needs an overlay/anchor expansion (or routing through the preview host), reserved headroom, zIndex/overflow handling. Not a frame swap. |
| Focus complexity | Medium-high — focus drives an overlay reveal; must keep `@FocusState`, `FocusRestorationPolicy`, and `restorePreviewFocusTarget` intact; expansion must not steal/lose focus. |
| Accessibility | Neutral — identity already stable; one label across both phases (keep current `ignore`+combined label). |
| Performance | Medium — poster (rest) always loaded; landscape (`art`) loaded for the focused/about-to-focus cell. Lazy row keeps offscreen cost out. |
| Epic 3 consistency | **Best fit** — Epic 3 explicitly owns "poster→landscape-on-focus"; this delivers it premium, no scope reduction. |

### Approach B — Landscape at rest → landscape on focus *(the prior report's pick)*

Every Recently Added cell is landscape (392×280) `art` `.fill`; focus = scale
only. Identical to Continue Watching.

| Dimension | Assessment |
| --- | --- |
| Visual quality | High and clean, **but a different product** — abandons poster-first density; Recently Added stops being a poster wall. |
| Engineering complexity | **Low** — delete the resting/landscape split, one full-bleed layer + scale. |
| Focus complexity | **Low** — scale only, no overlay, no headroom. |
| Accessibility | Neutral. |
| Performance | **Best** — one image per card. |
| Epic 3 consistency | **Conflicts** — Epic 3's stated behaviour is poster→landscape; choosing B because A is hard is a **silent scope reduction** (Constitution §3) unless there is a real product reason to prefer landscape-rest here. |

### Approach C — Poster at rest → larger poster on focus → landscape preview after dwell

Poster rest; focus scales the **poster** first; after a short dwell, cross-fade to
a landscape preview inside an expanded overlay.

| Dimension | Assessment |
| --- | --- |
| Visual quality | **Highest ceiling** — most "alive"; closest to a premium streaming feel. |
| Engineering complexity | **Highest** — everything in A plus a dwell-timer state machine and a two-phase reveal; interacts with the existing tap-to-preview carousel (risk of two competing "preview" concepts). |
| Focus complexity | **Highest** — timed reveal, cancel-on-defocus, Reduce-Motion must collapse the two phases into one instant state. |
| Accessibility | Hardest — a timed visual change must not change the a11y element or fire mid-dwell; needs care. |
| Performance | Same image cost as A + a timer per focused cell. |
| Epic 3 consistency | Exceeds the goal; more than Epic 3 scoped. Good *future* ceiling, not the next slice. |

## 6. Recommended architecture

**Adopt Approach A — poster at rest → landscape on focus, implemented as an
overlay expansion over a stable poster-shaped grid.** Reasons, per the Engineering
Constitution (not ease):

- **No scope reduction (§3).** Approach B drops a behaviour Epic 3 explicitly owns
  to avoid a geometry fix. There is no product reason landscape-rest is *better*
  here — it is just easier. The intended experience stays.
- **No half-fix / no workaround-as-final (§1, §2).** Fixing a frame-aspect bug by
  deleting the interaction is a half-fix. The real fix is correct geometry.
- **Maintainability / reuse over hand-rolled hacks (§4, §14).** Do **not** grow
  the in-row cell and fight reflow with ad-hoc offsets. Rivulet already has a
  focus/overlay architecture for "lift one item into a richer presentation":
  `PreviewOverlayHost` / `PreviewContainerViewController` / `previewSourceAnchor` /
  `PreviewContext`. The landscape "expanded" presentation is the same shape of
  problem. Either (a) route the focus expansion through that existing overlay
  layer, or (b) if focus-time (not tap-time) expansion doesn't fit that host,
  build a small dedicated focus-overlay that mirrors its anchor/zIndex/headroom
  approach. Decide this in the slice's design step before coding.

### Concrete shape of the correct implementation (for the future slice — not built here)

1. **Resting frame becomes poster-shaped.** `.posterExpandsToLandscape` resting
   layer renders the poster `.fill` in a **260×390** frame (poster aspect) — no
   gutters. Introduce a poster footprint for this style rather than reusing the
   `continueWatching` landscape dimensions for the resting state.
2. **Focused presentation is a landscape overlay.** On focus, present the
   landscape composition (`art` + logo + Rating·Year·Runtime) at landscape aspect,
   **drawn above neighbours** (raised zIndex, clip disabled) anchored to the
   resting cell, so the horizontal grid does **not** reflow. Reserve row vertical
   headroom for the larger presentation.
3. **Keep the host Button's ownership intact.** Selection, `previewSourceAnchor`,
   `@FocusState focusedItemId`, `FocusRestorationPolicy`, `restorePreviewFocusTarget`,
   and the context menu stay exactly as they are — the visual changes, the wiring
   does not (the no-regression lever proven in ADO-01/ADO-02).
4. **Art-less fallback.** When `art` is absent, `resolveStyle` already degrades to
   `.poster` (poster rest, poster focus-scale) — graceful, still gutter-free
   because the frame is poster-shaped. (Optional richer fallback: blurred-poster
   landscape fill, only if a real library shows too many art-less items.)
5. **Preserve a11y + Reduce Motion** exactly as today (combined label, instant
   swap when reduced).

This keeps the policy layer (`ContentPresentationPolicy`,
`ArtworkFallbackPolicy`, `MetadataHierarchyPolicy`) and the mapper unchanged in
spirit; the change is **frame geometry + a focus overlay**, the two things
actually broken/missing.

### Honest note on the prior report

The prior *Landscape Artwork Availability Report* was correct that the artwork
exists and that the focused state works. Its recommendation (Approach B) is a
legitimate *product* option, but it was framed as the fix for a *visual* defect —
and as a fix it is a scope reduction: it removes poster→landscape rather than
correcting its geometry. This audit supersedes that recommendation **unless the
user makes a deliberate product decision** that Recently Added should be a
landscape shelf (Approach B), in which case B is cheap and clean. That is a
product call, not a "the data forces it" call.

## 7. Required future adoption slice

A single bounded slice (proposed **ADO-02C: correct poster→landscape geometry**),
**not started here**:

- Add a poster-shaped resting footprint for `.posterExpandsToLandscape`
  (poster `.fill`, no gutters).
- Implement the focused landscape **overlay expansion** with reserved headroom and
  no horizontal reflow — first evaluating reuse of `PreviewOverlayHost`/
  `PreviewContainerViewController` vs a dedicated focus overlay (design step).
- Keep the host Button wiring and all focus/restoration behaviour unchanged.
- Tests: geometry/style selection (poster-rest vs landscape-focus), art-less
  degrade, no token leak, a11y-label stability across states, Reduce-Motion
  instant swap.
- **On-device/simulator visual + VoiceOver confirmation is the user's step** — the
  unit tests cannot prove the overlay doesn't reflow/clip (the gap that produced
  this whole audit).

Defer Approach C (dwell-delayed preview) as a later ceiling once A is live and
validated.

## 8. Risks

- **Overlay expansion vs scroll/focus.** An overflowing focused overlay must not
  be clipped, must not reflow neighbours, and must not drop/steal focus. Highest
  technical risk; mitigated by reusing the existing preview-overlay anchor model
  rather than ad-hoc zIndex.
- **Two "preview" concepts.** Rivulet already has a **tap**-triggered preview
  carousel (`onPreviewRequested` fires on Button action). A **focus**-triggered
  landscape expand must be reconciled with it so users don't get two competing
  expansions. Design-step decision.
- **Row height with mixed shapes.** Reserving headroom for the landscape overlay
  must not add dead vertical space to poster rest. Needs layout care.
- **Art-less items.** Degrade-to-poster is fine; verify proportion on a real
  library (`DEBT-E1-PR1-004`).
- **Scope discipline.** Approach A is genuinely more work than B; do not let that
  pressure silently slide back to B without an explicit product decision.

## 9. Dependencies

- Existing presentation policies + `PlexContentCardMapper` (present, reusable).
- Existing focus/preview overlay system: `PreviewOverlayHost`,
  `PreviewContainerViewController`, `previewSourceAnchor`, `PreviewContext`
  (present — candidate host for the expansion).
- `FocusRestorationPolicy`, `restorePreviewFocusTarget`, `@FocusState` row wiring
  (present — must remain intact).
- A poster-shaped footprint constant for the resting state (new; small).
- No new provider, no Epic 1 boundary, no playback, no project-setting change.

## 10. Recommendation summary

| | Verdict |
| --- | --- |
| Is the screenshot proof to abandon poster→landscape? | **No.** It's a frame-aspect (geometry) bug, not an interaction failure. |
| Geometry incorrect? | **Yes** — landscape frame at rest holding a portrait poster (~103 px gutters/side). |
| Artwork choice incorrect? | **No** — poster-rest/landscape-focus is correct *for the intended interaction*. |
| Both incorrect? | Geometry yes; artwork no. |
| Recommended approach | **A** — poster-shaped rest + landscape **overlay** expand on focus, reusing the existing overlay architecture. |
| When is B acceptable? | Only as a deliberate **product** choice to make Recently Added a landscape shelf — not as a defect fix. |
| Follow-up slice | **ADO-02C** (geometry + overlay expansion). Not started. Awaiting authorization. |
