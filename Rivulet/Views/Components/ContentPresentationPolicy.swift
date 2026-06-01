//
//  ContentPresentationPolicy.swift
//  Rivulet
//
//  E3-PR6 — the canonical Content Presentation System (pure policy layer).
//
//  Epic 3 owns how content is presented across cards, previews, and detail:
//  the card style, the title treatment (logo vs text), the artwork choice, the
//  metadata hierarchy, technical badges, content ratings, and runtime. This file
//  is the pure, unit-tested decision layer; SwiftUI views consume it. It holds
//  NO playback logic — inputs are already-resolved presentation values (strings/
//  flags), so nothing here touches the Epic 4 playback boundary. All types are
//  `nonisolated` value logic, callable and testable from any context.
//
//  Distinctness: this drives a close, first-party tvOS feel using the user's own
//  media. It encodes no Apple-owned asset, name, or trade dress.
//

import Foundation

// MARK: - Presentation style

/// How a content card is presented. Centralized, enum-based (never raw bools),
/// reusable, and extensible for future styles.
nonisolated enum ContentPresentationStyle: String, CaseIterable, Sendable {
    /// Landscape artwork card with lower-left title/logo overlay.
    case landscape
    /// Portrait poster card.
    case poster
    /// Poster at rest that transforms into a landscape card on focus.
    case posterExpandsToLandscape

    static let `default`: ContentPresentationStyle = .poster
}

nonisolated enum ContentPresentationPolicy {
    /// Resolves the effective style from the user's preferred style and whether
    /// landscape artwork is actually available. Styles that need landscape art
    /// gracefully degrade to `.poster` when it is missing, so a card never
    /// renders an empty landscape frame.
    static func resolveStyle(
        preferred: ContentPresentationStyle,
        hasLandscapeArtwork: Bool
    ) -> ContentPresentationStyle {
        switch preferred {
        case .poster:
            return .poster
        case .landscape, .posterExpandsToLandscape:
            return hasLandscapeArtwork ? preferred : .poster
        }
    }

    /// Whether the landscape composition (artwork + metadata overlay) is shown
    /// for a resolved style and focus state. `.landscape` always shows it;
    /// `.poster` never does; `.posterExpandsToLandscape` shows it only on focus
    /// (poster-shaped at rest → landscape on focus).
    static func showsLandscapeComposition(style: ContentPresentationStyle, isFocused: Bool) -> Bool {
        switch style {
        case .landscape: return true
        case .poster: return false
        case .posterExpandsToLandscape: return isFocused
        }
    }
}

// MARK: - Title treatment (logo vs text)

/// The resolved way to render a title. Never blocks rendering: falls back to
/// text when no logo image is available.
nonisolated enum TitleTreatment: Equatable {
    case logo(URL)
    case text(String)
}

nonisolated enum TitleTreatmentPolicy {
    /// Logo source order: Plex logo → TMDb logo → TVDb logo → text title.
    /// The first non-nil, valid URL wins; otherwise the text title.
    static func resolve(
        plexLogo: URL?,
        tmdbLogo: URL?,
        tvdbLogo: URL?,
        title: String
    ) -> TitleTreatment {
        if let url = plexLogo ?? tmdbLogo ?? tvdbLogo {
            return .logo(url)
        }
        return .text(title)
    }
}

// MARK: - Artwork fallback

/// The resolved artwork choice for a card. `.placeholder` guarantees a card
/// always has something to render.
nonisolated enum CardArtwork: Equatable {
    case landscape(URL)
    case backdropCrop(URL)
    case posterDerived(URL)
    case placeholder
}

nonisolated enum ArtworkFallbackPolicy {
    /// Card artwork order: landscape → fanart/backdrop crop → poster-derived →
    /// generic placeholder. First available wins.
    static func resolve(
        landscape: URL?,
        backdrop: URL?,
        poster: URL?
    ) -> CardArtwork {
        if let landscape { return .landscape(landscape) }
        if let backdrop { return .backdropCrop(backdrop) }
        if let poster { return .posterDerived(poster) }
        return .placeholder
    }
}

// MARK: - Runtime

nonisolated enum RuntimeFormatter {
    /// Formats a runtime in minutes as "2h 32m" / "47m". Hours are omitted when
    /// zero; returns nil for non-positive input (nothing to show).
    static func format(minutes: Int?) -> String? {
        guard let minutes, minutes > 0 else { return nil }
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }
}

// MARK: - Content rating

nonisolated enum ContentRatingPresentation {
    /// Trims and normalises a rating string for the bordered chip; returns nil
    /// when there is nothing meaningful to show. Does not invent ratings.
    static func normalized(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

// MARK: - Technical badges

/// Ordered, de-spammed technical badges for a media item. The policy keeps at
/// most one badge per dimension in the canonical order: resolution → video
/// format → audio format (e.g. "4K • Dolby Vision • Atmos").
nonisolated enum TechnicalBadgePolicy {
    /// Highest-value first. Used to pick a single badge when several candidates
    /// exist for one dimension.
    static let videoPriority = ["Dolby Vision", "HDR10+", "HDR10", "HDR"]
    static let audioPriority = ["Dolby Atmos", "Atmos", "DTS:X", "TrueHD", "DTS-HD MA", "DTS-HD", "7.1", "5.1"]

    /// Picks the highest-priority candidate present (case-insensitive match on
    /// the priority list), preserving the priority-list spelling.
    static func highestPriority(from candidates: [String], order: [String]) -> String? {
        let lowered = Set(candidates.map { $0.lowercased() })
        return order.first { lowered.contains($0.lowercased()) }
    }

    /// Builds the ordered badge row. Each dimension contributes at most one
    /// badge; nil/empty dimensions are skipped; order is resolution → video →
    /// audio. Resolution is shown as-is (callers pass "4K" etc.); HD/SD callers
    /// can pass nil to omit, avoiding badge spam.
    static func badges(resolution: String?, video: String?, audio: String?) -> [String] {
        var out: [String] = []
        for value in [resolution, video, audio] {
            if let value, !value.trimmingCharacters(in: .whitespaces).isEmpty {
                out.append(value)
            }
        }
        return out
    }
}

// MARK: - Metadata hierarchy

/// The canonical content metadata hierarchy, assembled deterministically:
///   Title treatment
///   Rating • Year • Runtime
///   <technical badges>
///   Short description
/// Views render these; the policy owns ordering and nil-filtering.
nonisolated struct ContentMetadataHierarchy: Equatable {
    let title: TitleTreatment
    /// Ordered "Rating • Year • Runtime" segments, nil-filtered.
    let infoLine: [String]
    /// Ordered technical badges (resolution → video → audio).
    let badges: [String]
    let description: String?
}

nonisolated enum MetadataHierarchyPolicy {
    static func build(
        title: TitleTreatment,
        rating: String?,
        year: Int?,
        runtimeMinutes: Int?,
        resolution: String?,
        video: String?,
        audio: String?,
        description: String?
    ) -> ContentMetadataHierarchy {
        var info: [String] = []
        if let rating = ContentRatingPresentation.normalized(rating) { info.append(rating) }
        if let year { info.append(String(year)) }
        if let runtime = RuntimeFormatter.format(minutes: runtimeMinutes) { info.append(runtime) }

        let trimmedDescription = description?.trimmingCharacters(in: .whitespacesAndNewlines)

        return ContentMetadataHierarchy(
            title: title,
            infoLine: info,
            badges: TechnicalBadgePolicy.badges(resolution: resolution, video: video, audio: audio),
            description: (trimmedDescription?.isEmpty == false) ? trimmedDescription : nil
        )
    }
}
