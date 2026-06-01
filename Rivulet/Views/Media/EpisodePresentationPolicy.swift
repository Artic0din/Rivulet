//
//  EpisodePresentationPolicy.swift
//  Rivulet
//
//  E3-PR10 — episode-card presentation + TV schedule/air-date labels.
//
//  Pure, `nonisolated`, unit-testable policy layer for episode cards and the
//  Apple-TV-style contextual labels (New / Recently Added / Season Finale / …).
//  All inputs are already-resolved presentation values derived from the existing
//  Plex model (index, air date, addedAt, leafCount, duration, viewOffset), so
//  nothing here touches playback, timeline/watch-state ownership, or any
//  external provider. Labels never mislead: when data is insufficient the policy
//  returns no label. No network, no Date.now() — callers pass a reference date
//  so results are deterministic and testable.
//

import Foundation

// MARK: - Schedule / availability labels

/// Contextual label for a show/episode surface. Only labels derivable from
/// existing Plex data are modelled; cadence labels ("New Episode Every
/// Wednesday") need data Plex does not expose and are intentionally omitted.
nonisolated enum ScheduleLabel: Equatable {
    case new
    case recentlyAdded
    case seasonFinale
    case continueWatching

    var displayText: String {
        switch self {
        case .new: return "New"
        case .recentlyAdded: return "Recently Added"
        case .seasonFinale: return "Season Finale"
        case .continueWatching: return "Continue Watching"
        }
    }
}

nonisolated enum ScheduleLabelPolicy {
    /// "New" if aired within this many days.
    static let newWithinDays = 14
    /// "Recently Added" if added within this many days.
    static let recentlyAddedWithinDays = 30

    struct Input: Equatable {
        var airedDaysAgo: Int?
        var addedDaysAgo: Int?
        var episodeIndex: Int?
        var seasonEpisodeCount: Int?
        var isInProgress: Bool = false
    }

    /// Deterministic label resolution, most-specific first. Returns nil when no
    /// label is warranted (graceful fallback — never a misleading label).
    static func label(for input: Input) -> ScheduleLabel? {
        if let idx = input.episodeIndex, let count = input.seasonEpisodeCount,
           count > 0, idx == count {
            return .seasonFinale
        }
        if let d = input.airedDaysAgo, d >= 0, d <= newWithinDays {
            return .new
        }
        if let d = input.addedDaysAgo, d >= 0, d <= recentlyAddedWithinDays {
            return .recentlyAdded
        }
        if input.isInProgress {
            return .continueWatching
        }
        return nil
    }

    /// Whole days between an event and a reference date (>= 0 in the past).
    /// nil when the event date is absent/unparseable.
    static func daysAgo(from event: Date?, reference: Date) -> Int? {
        guard let event else { return nil }
        let seconds = reference.timeIntervalSince(event)
        return Int(seconds / 86_400)
    }

    /// Parses Plex `originallyAvailableAt` ("yyyy-MM-dd") to a Date (UTC),
    /// nil when absent/invalid.
    static func parseAirDate(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: String(raw.prefix(10)))
    }
}

// MARK: - Episode card presentation

// ADO-01B: the standalone `EpisodeContentCard` view and its `EpisodeCardModel`
// were retired — the production `EpisodeCard` (in `MediaDetailView`) is the live,
// richer episode card and consumes the resolved-values helpers below directly.
nonisolated enum EpisodeCardPresentation {
    /// "EPISODE 13" (uppercase, Apple-TV-style), or "EPISODE" when index absent.
    static func episodeLabel(index: Int?) -> String {
        if let index { return "EPISODE \(index)" }
        return "EPISODE"
    }

    /// Combined VoiceOver label for an episode card: episode number, title,
    /// runtime, and state. Used live by the production `EpisodeCard`, which works
    /// in agnostic `MediaItem` terms (already-formatted runtime + progress).
    /// `episodeLabel` is presented as-is (capitalized) so an "S06E13"-style
    /// prefix label reads naturally too.
    static func accessibilityLabel(
        episodeLabel: String,
        title: String,
        runtime: String?,
        isWatched: Bool,
        progress: Double?
    ) -> String {
        var parts: [String] = [episodeLabel.capitalized, title]
        if let runtime { parts.append(runtime) }
        if isWatched {
            parts.append("Watched")
        } else if let progress {
            parts.append("\(Int(progress * 100)) percent watched")
        }
        return parts.joined(separator: ", ")
    }
}
