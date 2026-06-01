//
//  TMDBContentStatus.swift
//  Rivulet
//
//  ADO-04 — bridges a decoded `TMDBStatusDetail` into the provider-agnostic
//  `ContentStatusInput` consumed by `ContentStatusPolicy`. Pure and
//  `nonisolated`: it only parses dates and maps fields, so it is fully
//  unit-testable and keeps `ContentStatusLabel` free of any TMDb concept.
//
//  Truthfulness: every future date is passed through as-is; the policy decides
//  whether it is still ahead of the reference date. Nothing is inferred — a
//  field that TMDb omits stays nil and yields no label.
//

import Foundation

nonisolated enum TMDBContentStatus {

    /// Builds a `ContentStatusInput` for the hero/detail from a TMDb status
    /// payload. `kind` comes from the title being a movie or show. Only
    /// future-facing fields + `seriesIsComplete` are populated here — past-facing
    /// signals (recentlyAdded/new/finale) are Plex/episode concerns and are left
    /// nil so the hero never shows a noisy generic "Recently Added" chip.
    static func input(
        from detail: TMDBStatusDetail,
        kind: ContentStatusKind,
        reference: Date
    ) -> ContentStatusInput {
        switch kind {
        case .movie:
            return ContentStatusInput(
                kind: .movie,
                // Unreleased movie with a known release date → "Coming <date>".
                comingSoonDate: isReleased(detail.status) ? nil : ContentStatusPolicy.parseAirDate(detail.releaseDate)
            )

        case .show, .season, .episode:
            let firstAir = ContentStatusPolicy.parseAirDate(detail.firstAirDate)
            let nextAir = ContentStatusPolicy.parseAirDate(detail.nextEpisodeToAir?.airDate)
            let lastAir = ContentStatusPolicy.parseAirDate(detail.lastEpisodeToAir?.airDate ?? detail.lastAirDate)
            // A season premiere only counts as such for real seasons (>= 1);
            // TMDb "specials" live in season 0 and must not read as a new season.
            let nextSeasonNumber = detail.nextEpisodeToAir?.seasonNumber ?? 1
            let nextIsSeasonStart = (detail.nextEpisodeToAir?.episodeNumber == 1) && nextSeasonNumber >= 1
            let hasAired = detail.lastAirDate != nil || detail.lastEpisodeToAir != nil

            // Premiere: the series itself has not aired yet.
            let premiere: Date? = (!hasAired) ? firstAir : nil
            // New season: next episode is episode 1 of a real season.
            let newSeason: Date? = (hasAired && nextIsSeasonStart) ? nextAir : nil

            // Mid-season upcoming episode: distinguish a currently-airing weekly
            // show (small gap since the last episode → "New Episode Every <day>")
            // from a show returning after a long break (→ "Returns <date>").
            var weekly: Weekday? = nil
            var returns: Date? = nil
            if hasAired, !nextIsSeasonStart, let next = nextAir, next > reference {
                let gapDays = lastAir.map { Int(next.timeIntervalSince($0) / 86_400) }
                if let gap = gapDays, gap >= 0, gap <= weeklyCadenceMaxGapDays {
                    weekly = weekday(of: next)
                } else if isReturning(detail.status) {
                    returns = next
                }
            }

            // Complete: ended/cancelled and no longer in production → all episodes available.
            let complete: Bool? = (isEnded(detail.status) && detail.inProduction != true) ? true : nil

            return ContentStatusInput(
                kind: kind,
                seriesIsComplete: complete,
                premiereDate: premiere,
                returnDate: returns,
                newSeasonDate: newSeason,
                weeklyReleaseDay: weekly
            )
        }
    }

    /// Largest last→next-episode gap (days) still treated as a weekly cadence.
    /// A fortnight of slack tolerates skipped weeks / scheduling drift.
    private static let weeklyCadenceMaxGapDays = 14

    /// Weekday of a date in UTC (air dates are UTC calendar days).
    private static func weekday(of date: Date) -> Weekday? {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? cal.timeZone
        return Weekday(rawValue: cal.component(.weekday, from: date))
    }

    /// Maps a Plex `type` string to the status kind.
    static func kind(fromPlexType type: String?) -> ContentStatusKind {
        switch type {
        case "movie": return .movie
        case "show": return .show
        case "season": return .season
        case "episode": return .episode
        default: return .movie
        }
    }

    // MARK: - Status helpers (TMDb status vocabulary)

    private static func isReleased(_ status: String?) -> Bool {
        status?.caseInsensitiveCompare("Released") == .orderedSame
    }

    private static func isReturning(_ status: String?) -> Bool {
        status?.caseInsensitiveCompare("Returning Series") == .orderedSame
    }

    private static func isEnded(_ status: String?) -> Bool {
        guard let status else { return false }
        return status.caseInsensitiveCompare("Ended") == .orderedSame
            || status.caseInsensitiveCompare("Canceled") == .orderedSame
            || status.caseInsensitiveCompare("Cancelled") == .orderedSame
    }
}
