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
        kind: ContentStatusKind
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
            let nextIsSeasonStart = (detail.nextEpisodeToAir?.episodeNumber == 1)
            let hasAired = detail.lastAirDate != nil || detail.lastEpisodeToAir != nil

            // Premiere: the series itself has not aired yet.
            let premiere: Date? = (!hasAired) ? firstAir : nil
            // New season: next episode is episode 1 of a season (and the series
            // has already aired at least once).
            let newSeason: Date? = (hasAired && nextIsSeasonStart) ? nextAir : nil
            // Returns: a returning series with an upcoming non-premiere episode.
            let returns: Date? = (hasAired && !nextIsSeasonStart && isReturning(detail.status)) ? nextAir : nil
            // Complete: ended/cancelled and no longer in production → all episodes available.
            let complete: Bool? = (isEnded(detail.status) && detail.inProduction != true) ? true : nil

            return ContentStatusInput(
                kind: kind,
                seriesIsComplete: complete,
                premiereDate: premiere,
                returnDate: returns,
                newSeasonDate: newSeason
            )
        }
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
