//
//  MetadataBadge.swift
//  Rivulet
//
//  ADO-06 — one small, rounded metadata badge used for both technical-format
//  badges (4K / Dolby Vision / Atmos / 5.1) and content ratings (PG-13 / TV-MA /
//  MA15+). Previously the detail page had a private `QualityBadge` (filled, for
//  technical badges) while content ratings rendered as a stroke-only outline of a
//  different size — two near-identical styles. This unifies them so a rating
//  reads as a first-class, consistent metadata badge rather than ad-hoc text.
//
//  Style is intentionally subtle (translucent fill + hairline stroke), matching
//  the prior `QualityBadge` so technical badges are visually unchanged.
//

import SwiftUI

/// A small, rounded, translucent metadata badge. `fontSize` lets a larger surface
/// (the home hero) use a slightly bigger badge while keeping the same shape/fill.
struct MetadataBadge: View {
    let text: String
    var fontSize: CGFloat = 13

    private let cornerRadius: CGFloat = 4

    var body: some View {
        Text(text)
            .font(.system(size: fontSize, weight: .semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.white.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.3), lineWidth: 0.5)
            )
            .foregroundStyle(.white)
    }
}

// MARK: - Rating display policy (pure)

/// Display-only normalisation for a content rating. It NEVER changes the rating
/// value or its source — it only strips a leading locale prefix that some Plex
/// agents prepend (e.g. "US:TV-MA" → "TV-MA", "de:16" → "16") and trims
/// whitespace, returning nil when there is nothing to show. The certification
/// itself is passed through verbatim.
nonisolated enum RatingBadgePolicy {
    static func displayRating(_ raw: String?) -> String? {
        guard let raw else { return nil }
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        // Strip a single leading "<country code>:" prefix (two ASCII letters).
        if let colon = value.firstIndex(of: ":") {
            let prefix = value[value.startIndex..<colon]
            if prefix.count == 2, prefix.allSatisfy({ $0.isLetter && $0.isASCII }) {
                value = String(value[value.index(after: colon)...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return value.isEmpty ? nil : value
    }
}
