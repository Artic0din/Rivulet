//
//  LandscapeContentCard.swift
//  Rivulet
//
//  E3-PR7 — landscape artwork card + poster→landscape-on-focus card.
//
//  A production-ready, self-contained content card that renders the canonical
//  Content Presentation System (E3-PR6): artwork with graceful fallback, a
//  lower-left title treatment (logo or text), an info line (Rating · Year ·
//  Runtime), and technical badges. It honours Reduce Motion, uses the design
//  tokens for focus emphasis, exposes one combined VoiceOver label, and triggers
//  NO network work on focus (artwork URLs are passed in, already resolved).
//
//  This component is additive: it does not replace existing card usages. Broad
//  adoption across Home/Library/Discover rows and on-device validation are the
//  remaining integration steps, tracked as debt (see E3-PR7 docs).
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

struct LandscapeContentCard: View {
    let model: ContentCardModel
    /// Presentation style. `.posterExpandsToLandscape` shows the poster at rest
    /// and the landscape composition on focus.
    var style: ContentPresentationStyle = .landscape

    @Environment(\.uiScale) private var scale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isFocused: Bool

    private var width: CGFloat { ScaledDimensions.continueWatchingWidth * scale }
    private var height: CGFloat { ScaledDimensions.continueWatchingHeight * scale }
    private var cornerRadius: CGFloat { ContentDesignTokens.Shape.cornerRadius }

    /// Whether the landscape composition (artwork + overlay) is shown. For the
    /// poster-expands style this is only when focused.
    private var showsLandscape: Bool {
        switch style {
        case .landscape: return true
        case .poster: return false
        case .posterExpandsToLandscape: return isFocused
        }
    }

    var body: some View {
        Button {
            // Selection is handled by the host; this component is presentation.
        } label: {
            ZStack(alignment: .bottomLeading) {
                artwork
                if showsLandscape {
                    overlay
                }
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .buttonStyle(CardButtonStyle())
        .focused($isFocused)
        .scaleEffect(isFocused ? ContentDesignTokens.Scale.rowFocused : ContentDesignTokens.Scale.resting)
        .animation(
            PreviewMotionPolicy.animation(ContentDesignTokens.Motion.rowFocus, reduceMotion: reduceMotion),
            value: isFocused
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ContentCardAccessibility.label(title: model.title, infoLine: model.infoLine, badges: model.badges))
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Artwork

    @ViewBuilder
    private var artwork: some View {
        // Poster style (and poster-at-rest) uses the poster image; landscape
        // composition uses the resolved landscape/backdrop artwork.
        let url = showsLandscape ? model.artwork.url : (model.posterURL ?? model.artwork.url)
        CachedAsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().aspectRatio(contentMode: .fill)
            case .empty:
                Rectangle().fill(Color(white: 0.15)).overlay { ProgressView().tint(.white.opacity(0.3)) }
            case .failure:
                placeholder
            }
        }
        .frame(width: width, height: height)
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
                        .frame(maxWidth: width * 0.6, maxHeight: height * 0.28, alignment: .leading)
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
