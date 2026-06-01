//
//  EpisodeContentCard.swift
//  Rivulet
//
//  E3-PR10 — Apple-TV-style episode card.
//
//  Additive, self-contained landscape episode card consuming the pure
//  EpisodeCardPresentation model: still artwork, "EPISODE n" label, title,
//  synopsis, runtime row, and optional watched/progress state, over a readable
//  gradient. Honours Reduce Motion, exposes one combined VoiceOver label, and
//  triggers no network on focus (still URL passed in resolved). Not yet wired
//  into production lists (see DEBT-E3-PR7-001 family); cannot regress.
//

import SwiftUI

struct EpisodeContentCard: View {
    let model: EpisodeCardModel
    let stillURL: URL?

    @Environment(\.uiScale) private var scale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isFocused: Bool

    private var width: CGFloat { ScaledDimensions.continueWatchingWidth * scale }
    private var height: CGFloat { ScaledDimensions.continueWatchingHeight * scale }
    private var cornerRadius: CGFloat { ContentDesignTokens.Shape.cornerRadius }

    var body: some View {
        Button {
            // Selection handled by the host; this component is presentation.
        } label: {
            VStack(alignment: .leading, spacing: 8 * scale) {
                artwork
                    .frame(width: width, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .overlay(alignment: .bottom) { progressBar }
                textBlock
            }
            .frame(width: width)
        }
        .buttonStyle(CardButtonStyle())
        .focused($isFocused)
        .scaleEffect(isFocused ? ContentDesignTokens.Scale.rowFocused : ContentDesignTokens.Scale.resting)
        .animation(
            PreviewMotionPolicy.animation(ContentDesignTokens.Motion.rowFocus, reduceMotion: reduceMotion),
            value: isFocused
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(EpisodeCardPresentation.accessibilityLabel(model))
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var artwork: some View {
        CachedAsyncImage(url: stillURL) { phase in
            switch phase {
            case .success(let image):
                image.resizable().aspectRatio(contentMode: .fill)
            case .empty:
                Rectangle().fill(Color(white: 0.15)).overlay { ProgressView().tint(.white.opacity(0.3)) }
            case .failure:
                Rectangle()
                    .fill(LinearGradient(colors: [Color(white: 0.18), Color(white: 0.12)], startPoint: .top, endPoint: .bottom))
                    .overlay { Image(systemName: "play.rectangle").font(.system(size: 30, weight: .light)).foregroundStyle(.white.opacity(0.3)) }
            }
        }
        .frame(width: width, height: height)
        .clipped()
        .overlay(alignment: .topTrailing) {
            if model.isWatched { WatchedCornerTag(cornerRadius: cornerRadius) }
        }
    }

    @ViewBuilder
    private var progressBar: some View {
        if let progress = model.progress {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.3))
                    Capsule().fill(.white).frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 10 * scale)
            .padding(.bottom, 8 * scale)
        }
    }

    private var textBlock: some View {
        VStack(alignment: .leading, spacing: 4 * scale) {
            Text(model.episodeLabel)
                .font(.system(size: (ContentDesignTokens.TypeRamp.cardSubtitle - 4) * scale, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
            Text(model.title)
                .font(.system(size: ContentDesignTokens.TypeRamp.cardSubtitle * scale, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            if let synopsis = model.synopsis {
                Text(synopsis)
                    .font(.system(size: (ContentDesignTokens.TypeRamp.cardSubtitle - 3) * scale))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            if let runtime = model.runtime {
                Text(runtime)
                    .font(.system(size: (ContentDesignTokens.TypeRamp.cardSubtitle - 4) * scale))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .frame(width: width, alignment: .leading)
    }
}

#if DEBUG
#Preview("Episode", traits: .fixedLayout(width: 460, height: 460)) {
    EpisodeContentCard(
        model: EpisodeCardModel(
            episodeLabel: "EPISODE 13",
            title: "Be Still My Heart",
            synopsis: "Elizabeth has difficulty impressing her visiting mother.",
            runtime: "40m",
            progress: 0.35,
            isWatched: false
        ),
        stillURL: nil
    )
}
#endif
