//
//  EpisodePresentationPolicy.swift
//  Rivulet
//
//  E3-PR10 — episode-card presentation helpers.
//
//  Pure, `nonisolated`, unit-testable presentation helpers for the live episode
//  card (label + combined VoiceOver summary). All inputs are already-resolved
//  presentation values, so nothing here touches playback, watch-state, or any
//  provider.
//
//  NOTE (ADO-03): the former `ScheduleLabel`/`ScheduleLabelPolicy` (the narrow
//  New/Recently Added/Season Finale tagger) was retired here and superseded by
//  the broader, future-proof Content Status Label System in
//  `Views/Components/ContentStatusLabel.swift`. There is intentionally one
//  status system, not two.
//

import Foundation

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
    /// optional content-status, runtime, and state. Used live by the production
    /// `EpisodeCard`, which works in agnostic `MediaItem` terms (already-formatted
    /// runtime + progress). `episodeLabel` is presented as-is (capitalized) so an
    /// "S06E13"-style prefix label reads naturally too. The status is announced
    /// ONLY when one is visible on the card (`statusLabel != nil`), so the spoken
    /// label never claims a badge the card isn't showing.
    static func accessibilityLabel(
        episodeLabel: String,
        title: String,
        statusLabel: ContentStatusLabel? = nil,
        runtime: String?,
        isWatched: Bool,
        progress: Double?
    ) -> String {
        var parts: [String] = [episodeLabel.capitalized, title]
        if let statusLabel { parts.append(statusLabel.displayText) }
        if let runtime { parts.append(runtime) }
        if isWatched {
            parts.append("Watched")
        } else if let progress {
            parts.append("\(Int(progress * 100)) percent watched")
        }
        return parts.joined(separator: ", ")
    }

    /// ADO-05: the single Plex-backed content-status label for an episode card,
    /// or nil when none is warranted. Pure and deterministic — the caller passes
    /// a `reference` date (no `Date.now()` here). Builds a per-episode
    /// `ContentStatusInput`, classifies it with `ContentStatusPolicy`, and keeps
    /// the result only if it is permitted on the `episodeCard` surface (so only
    /// Season Finale / New Episode Today / New Episode can surface — show-level
    /// editorial labels never leak onto a per-episode card).
    ///
    /// Guards (truthful-by-construction):
    ///   - Specials / season 0 (and an unknown season) never read as a finale:
    ///     the finale inputs are withheld unless the season number is a regular
    ///     season (>= 1).
    ///   - A finale needs a valid episode index AND a valid season episode count
    ///     (enforced by `ContentStatusPolicy`: `count > 0 && index == count`).
    ///   - Future air dates never produce "New Episode Today" / "New Episode":
    ///     `airedDaysAgo` is a UTC calendar-day delta, negative for the future,
    ///     and the policy fires only on `== 0` (today) or `1...newWithinDays`.
    static func episodeStatusLabel(
        episodeIndex: Int?,
        seasonNumber: Int?,
        seasonEpisodeCount: Int?,
        airDate: Date?,
        reference: Date
    ) -> ContentStatusLabel? {
        let seasonIsRegular = (seasonNumber ?? 0) >= 1
        let input = ContentStatusInput(
            kind: .episode,
            airedDaysAgo: airedDaysAgo(airDate: airDate, reference: reference),
            episodeIndex: seasonIsRegular ? episodeIndex : nil,
            seasonEpisodeCount: seasonIsRegular ? seasonEpisodeCount : nil
        )
        guard let label = ContentStatusPolicy.classify(input, reference: reference),
              ContentStatusPlacement.allows(label, on: .episodeCard)
        else { return nil }
        return label
    }

    /// Whole UTC calendar days between an air date and the reference day:
    /// `0` same day, positive in the past, negative in the future. Calendar-day
    /// (not raw-interval) math avoids a date that is hours into the future
    /// reading as "today".
    private static func airedDaysAgo(airDate: Date?, reference: Date) -> Int? {
        guard let airDate else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? cal.timeZone
        let from = cal.startOfDay(for: airDate)
        let to = cal.startOfDay(for: reference)
        return cal.dateComponents([.day], from: from, to: to).day
    }
}
