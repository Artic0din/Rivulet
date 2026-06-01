//
//  LandscapeContentCard.swift
//  Rivulet
//
//  E3-PR7 — landscape artwork card + poster→landscape-on-focus card.
//  ADO-02C — corrected poster→landscape geometry.
//
//  A production-ready, self-contained content card that renders the canonical
//  Content Presentation System (E3-PR6): artwork with graceful fallback, a
//  lower-left title treatment (logo or text), an info line (Rating · Year ·
//  Runtime), and technical badges. It honours Reduce Motion, uses the design
//  tokens for focus emphasis, exposes one combined VoiceOver label, and triggers
//  NO network work on focus (artwork URLs are passed in, already resolved).
//
//  Geometry (ADO-02C): the cell reserves a *poster-shaped* footprint for
//  `.posterExpandsToLandscape` (so the poster artwork fills it edge-to-edge with
//  NO black gutters), and the landscape composition on focus is drawn as an
//  `.overlay` that OVERFLOWS that stable footprint — it never resizes the cell's
//  layout, so the row never reflows and neighbours never reposition. The host
//  row raises the focused cell's `zIndex` so the overflow draws above its
//  neighbours rather than being occluded. `.landscape` cards keep a landscape
//  footprint and scale-only focus, matching `ContinueWatchingCard`.
//
//  This component is additive beyond the rows that adopt it. Broad adoption
//  across the remaining Home/Library/Discover rows is tracked as debt.
//

import SwiftUI

// MARK: - Card model

/// Pre-resolved presentation values for a content card. The caller resolves
/// these via `ContentPresentationPolicy`/`TitleTreatmentPolicy`/etc., so the
/// card itself performs no fallback or fetch logic beyond image loading.
nonisolated struct ContentCardModel: Equatable {
    let title: String
    let titleTreatment: TitleTreatment
    let artwork: CardArtwork
    let posterURL: URL?
    let infoLine: [String]
    let badges: [String]

    init(
        title: String,
        titleTreatment: TitleTreatment,
        artwork: CardArtwork,
        posterURL: URL?,
        infoLine: [String],
        badges: [String]
    ) {
        self.title = title
        self.titleTreatment = titleTreatment
        self.artwork = artwork
        self.posterURL = posterURL
        self.infoLine = infoLine
        self.badges = badges
    }
}

// MARK: - Accessibility label (pure, testable)

nonisolated enum ContentCardAccessibility {
    /// One combined VoiceOver label: title, then info-line segments, then
    /// badges — read as a single element so the card is not a fragmented stack.
    static func label(title: String, infoLine: [String], badges: [String]) -> String {
        var parts: [String] = [title]
        parts.append(contentsOf: infoLine)
        parts.append(contentsOf: badges)
        return parts.joined(separator: ", ")
    }
}

// MARK: - Artwork URL resolution helper

private extension CardArtwork {
    var url: URL? {
        switch self {
        case .landscape(let u), .backdropCrop(let u), .posterDerived(let u): return u
        case .placeholder: return nil
        }
    }
}

// MARK: - Landscape content card

/// Presentation-only landscape card visual. It is rendered as the *label* of a
/// host row's focusable `Button` (which owns selection/preview/focus/context
/// menu), exactly like `MediaPosterCard`/`ContinueWatchingCard` — so this view
/// is NOT a button itself. Focus is passed in (`isFocused`) by the host row.
struct LandscapeContentCard: View {
    let model: ContentCardModel
    /// Presentation style. `.posterExpandsToLandscape` shows the poster at rest
    /// and the landscape composition on focus.
    var style: ContentPresentationStyle = .landscape
    /// Host-tracked focus (mirrors `ContinueWatchingCard`); drives the
    /// poster→landscape reveal and the focus emphasis.
    var isFocused: Bool = false

    @Environment(\.uiScale) private var scale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Landscape composition size (matches ContinueWatchingCard): 392 × 280.
    private var landscapeWidth: CGFloat { ScaledDimensions.continueWatchingWidth * scale }
    private var landscapeHeight: CGFloat { ScaledDimensions.continueWatchingHeight * scale }
    // Poster footprint (matches MediaPosterCard): 260 × 390 — a true 2:3 frame
    // the poster fills edge-to-edge, so there are no side gutters at rest.
    private var posterWidth: CGFloat { ScaledDimensions.posterWidth * scale }
    private var posterHeight: CGFloat { ScaledDimensions.posterHeight * scale }
    private var cornerRadius: CGFloat { ContentDesignTokens.Shape.cornerRadius }

    /// The shape the cell reserves for layout. For `.posterExpandsToLandscape`
    /// this is poster (portrait) — the landscape state is an overflow overlay,
    /// not a layout change — so the row never reflows.
    private var footprintShape: CardShape {
        ContentPresentationPolicy.footprintShape(style: style)
    }
    private var footprintWidth: CGFloat {
        footprintShape == .landscape ? landscapeWidth : posterWidth
    }
    private var footprintHeight: CGFloat {
        footprintShape == .landscape ? landscapeHeight : posterHeight
    }

    /// Whether the landscape composition is shown — delegated to the tested
    /// `ContentPresentationPolicy.showsLandscapeComposition`.
    private var showsLandscape: Bool {
        ContentPresentationPolicy.showsLandscapeComposition(style: style, isFocused: isFocused)
    }

    var body: some View {
        // The cell reserves a STABLE poster-shaped footprint (for
        // `.posterExpandsToLandscape`); the landscape composition on focus is an
        // `.overlay` that overflows that footprint without changing the cell's
        // layout size — so the row never reflows and neighbours never move. Both
        // images load at render time (never on focus), so focus triggers no
        // network fetch. The poster and landscape are cross-faded by opacity;
        // under Reduce Motion the swap is instant (no animation, no info lost).
        posterRestingLayer
            .frame(width: footprintWidth, height: footprintHeight)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .opacity(showsLandscape ? 0 : 1)
            .overlay {
                landscapeLayer
                    .frame(width: landscapeWidth, height: landscapeHeight)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .opacity(showsLandscape ? 1 : 0)
                    // Visual only — the host Button owns interaction; the overlay
                    // must not extend the focusable/hit-test area beyond the cell.
                    .allowsHitTesting(false)
            }
            .scaleEffect(isFocused ? ContentDesignTokens.Scale.rowFocused : ContentDesignTokens.Scale.resting)
            .animation(
                PreviewMotionPolicy.animation(ContentDesignTokens.Motion.rowFocus, reduceMotion: reduceMotion),
                value: isFocused
            )
            // Accessibility identity is stable across resting/focused states — the
            // same combined label regardless of which visual layer is shown.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(ContentCardAccessibility.label(title: model.title, infoLine: model.infoLine, badges: model.badges))
            .accessibilityAddTraits(.isButton)
    }

    // MARK: - Landscape layer (focused / always-landscape)

    private var landscapeLayer: some View {
        ZStack(alignment: .bottomLeading) {
            CachedAsyncImage(url: model.artwork.url ?? model.posterURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                case .empty:
                    Rectangle().fill(Color(white: 0.15)).overlay { ProgressView().tint(.white.opacity(0.3)) }
                case .failure:
                    placeholder
                }
            }
            .frame(width: landscapeWidth, height: landscapeHeight)
            .clipped()
            overlay
        }
    }

    // MARK: - Poster resting layer (poster-shaped, fills the 2:3 footprint)

    private var posterRestingLayer: some View {
        // The poster `.fill`s a true 2:3 frame, so there are NO side gutters: the
        // resting state reads as a clean poster, matching `MediaPosterCard`.
        CachedAsyncImage(url: model.posterURL ?? model.artwork.url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().aspectRatio(contentMode: .fill)
            case .empty:
                ZStack { Color(white: 0.10); ProgressView().tint(.white.opacity(0.3)) }
            case .failure:
                placeholder
            }
        }
        .frame(width: footprintWidth, height: footprintHeight)
        .clipped()
    }

    private var placeholder: some View {
        Rectangle()
            .fill(LinearGradient(colors: [Color(white: 0.18), Color(white: 0.12)], startPoint: .top, endPoint: .bottom))
            .overlay {
                Image(systemName: "film")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(.white.opacity(0.3))
            }
    }

    // MARK: - Lower-left overlay (title treatment + metadata)

    private var overlay: some View {
        VStack(alignment: .leading, spacing: 6 * scale) {
            Spacer(minLength: 0)
            titleView
            if !model.infoLine.isEmpty {
                Text(model.infoLine.joined(separator: " · "))
                    .font(.system(size: ContentDesignTokens.TypeRamp.cardSubtitle * scale, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
            }
            if !model.badges.isEmpty {
                Text(model.badges.joined(separator: " • "))
                    .font(.system(size: (ContentDesignTokens.TypeRamp.cardSubtitle - 3) * scale, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
            }
        }
        .padding(16 * scale)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .background(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.35),
                    .init(color: .black.opacity(0.55), location: 0.75),
                    .init(color: .black.opacity(0.85), location: 1.0)
                ],
                startPoint: .top, endPoint: .bottom
            )
        )
    }

    @ViewBuilder
    private var titleView: some View {
        switch model.titleTreatment {
        case .logo(let url):
            CachedAsyncImage(url: url) { phase in
                if case .success(let image) = phase {
                    image.resizable().aspectRatio(contentMode: .fit)
                        .frame(maxWidth: landscapeWidth * 0.6, maxHeight: landscapeHeight * 0.28, alignment: .leading)
                } else {
                    titleText // graceful fallback while/if the logo is unavailable
                }
            }
        case .text(let title):
            Text(title)
                .font(.system(size: ContentDesignTokens.TypeRamp.cardTitle * scale, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(2)
        }
    }

    private var titleText: some View {
        Text(model.title)
            .font(.system(size: ContentDesignTokens.TypeRamp.cardTitle * scale, weight: .bold))
            .foregroundStyle(.white)
            .lineLimit(2)
    }
}

#if DEBUG
#Preview("Landscape", traits: .fixedLayout(width: 500, height: 360)) {
    LandscapeContentCard(
        model: ContentCardModel(
            title: "Dune: Part Two",
            titleTreatment: .text("Dune: Part Two"),
            artwork: .placeholder,
            posterURL: nil,
            infoLine: ["M", "2024", "2h 46m"],
            badges: ["4K", "Dolby Vision", "Atmos"]
        ),
        style: .landscape
    )
}
#endif
