//
//  ContentStatusLabel.swift
//  Rivulet
//
//  ADO-03 — Content Status Label System.
//
//  Editorial-style status messaging that answers "why is this title being
//  surfaced right now?" — e.g. "Season Finale", "New Episode Today", "Premieres
//  Friday", "Returns 12 Sep", "New Season Aug". This supersedes the narrow
//  `ScheduleLabelPolicy` (retired) with one future-proof model that spans current
//  AND future content, episodic AND seasonal, TV AND movies, and both the Plex
//  and TMDb data sources — so a second system is never needed.
//
//  Design rules:
//   - Pure, `nonisolated`, fully unit-testable. No `Date.now()` inside — callers
//     pass a reference date so results are deterministic.
//   - Truthful only: a label is emitted ONLY when the data backing it exists.
//     Future-facing cases (premieres/returns/newSeason/weekly cadence/comingSoon)
//     require TMDb fields that are NOT modelled yet (see DEBT-E3-ADO03-001); their
//     inputs are optional and simply stay nil until that expansion lands, at which
//     point the labels light up with no further architecture work.
//   - No playback, provider, auth, token, or watch-state involvement — value
//     logic over already-resolved presentation inputs only.
//

import Foundation

// MARK: - Weekday (for weekly-cadence labels)

nonisolated enum Weekday: Int, CaseIterable, Sendable, Equatable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    var displayName: String {
        switch self {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        }
    }
}

// MARK: - Content status label

/// A single editorial status for a title. `displayText` is plain-language and
/// generic (no copied wording/trade dress). Dated cases format with a short,
/// locale-aware "d MMM" style.
nonisolated enum ContentStatusLabel: Equatable, Sendable {
    // Current content (Plex-backed, available today)
    case seasonFinale
    case episodeAvailableToday
    case newEpisode
    case allEpisodesAvailable
    case recentlyAdded

    // Future content (require TMDb expansion — DEBT-E3-ADO03-001)
    case premieres(Date)
    case returns(Date)
    case newSeason(Date)
    case newEpisodeWeekly(Weekday)
    case comingSoon(Date)

    var displayText: String {
        switch self {
        case .seasonFinale: return "Season Finale"
        case .episodeAvailableToday: return "New Episode Today"
        case .newEpisode: return "New Episode"
        case .allEpisodesAvailable: return "All Episodes Available"
        case .recentlyAdded: return "Recently Added"
        case .premieres(let date): return "Premieres \(Self.shortDate(date))"
        case .returns(let date): return "Returns \(Self.shortDate(date))"
        case .newSeason(let date): return "New Season \(Self.monthYear(date))"
        case .newEpisodeWeekly(let day): return "New Episode Every \(day.displayName)"
        case .comingSoon(let date): return "Coming \(Self.shortDate(date))"
        }
    }

    /// Whether this label is future-facing (needs TMDb expansion to ever appear).
    var isFutureFacing: Bool {
        switch self {
        case .premieres, .returns, .newSeason, .newEpisodeWeekly, .comingSoon: return true
        default: return false
        }
    }

    private static func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("dMMM")
        return f.string(from: date)
    }

    private static func monthYear(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("MMMyyyy")
        return f.string(from: date)
    }
}

// MARK: - Classifier input

nonisolated enum ContentStatusKind: Sendable, Equatable {
    case movie, show, season, episode
}

nonisolated struct ContentStatusInput: Equatable, Sendable {
    var kind: ContentStatusKind

    // Current (Plex-backed)
    /// Whole days since the title/episode aired (>= 0 in past); nil if unknown.
    var airedDaysAgo: Int?
    /// Whole days since the item was added to the library (>= 0); nil if unknown.
    var addedDaysAgo: Int?
    /// Episode number within its season (Plex `index`).
    var episodeIndex: Int?
    /// Total episodes in the season (Plex `leafCount`/`childProgress.total`).
    var seasonEpisodeCount: Int?
    /// True only when a series is known-complete and every episode is present.
    /// Conservative: leave nil unless genuinely known (Plex cannot confirm
    /// "ended", so this stays nil today — see audit).
    var seriesIsComplete: Bool?

    // Future (TMDb expansion — currently always nil; see DEBT-E3-ADO03-001)
    var premiereDate: Date?
    var returnDate: Date?
    var newSeasonDate: Date?
    var weeklyReleaseDay: Weekday?
    var comingSoonDate: Date?

    init(
        kind: ContentStatusKind,
        airedDaysAgo: Int? = nil,
        addedDaysAgo: Int? = nil,
        episodeIndex: Int? = nil,
        seasonEpisodeCount: Int? = nil,
        seriesIsComplete: Bool? = nil,
        premiereDate: Date? = nil,
        returnDate: Date? = nil,
        newSeasonDate: Date? = nil,
        weeklyReleaseDay: Weekday? = nil,
        comingSoonDate: Date? = nil
    ) {
        self.kind = kind
        self.airedDaysAgo = airedDaysAgo
        self.addedDaysAgo = addedDaysAgo
        self.episodeIndex = episodeIndex
        self.seasonEpisodeCount = seasonEpisodeCount
        self.seriesIsComplete = seriesIsComplete
        self.premiereDate = premiereDate
        self.returnDate = returnDate
        self.newSeasonDate = newSeasonDate
        self.weeklyReleaseDay = weeklyReleaseDay
        self.comingSoonDate = comingSoonDate
    }
}

// MARK: - Classifier

nonisolated enum ContentStatusPolicy {
    /// "New Episode" if aired within this many days (and not today).
    static let newWithinDays = 14
    /// "Recently Added" if added within this many days.
    static let recentlyAddedWithinDays = 30

    /// Resolves the single most editorially-relevant status for a title, or nil
    /// when none is warranted. Precedence: future events first (most editorial),
    /// then current-content signals. Future cases fire only when their TMDb date
    /// is present AND still in the future relative to `reference`.
    static func classify(_ input: ContentStatusInput, reference: Date) -> ContentStatusLabel? {
        // --- Future-facing (TMDb; nil today) -------------------------------
        if let d = input.premiereDate, d > reference { return .premieres(d) }
        if let d = input.newSeasonDate, d > reference { return .newSeason(d) }
        if let d = input.returnDate, d > reference { return .returns(d) }
        if let d = input.comingSoonDate, d > reference { return .comingSoon(d) }
        if let day = input.weeklyReleaseDay { return .newEpisodeWeekly(day) }

        // --- Current content (Plex) ----------------------------------------
        if let idx = input.episodeIndex, let count = input.seasonEpisodeCount,
           count > 0, idx == count {
            return .seasonFinale
        }
        if let aired = input.airedDaysAgo, aired == 0 {
            return .episodeAvailableToday
        }
        if let aired = input.airedDaysAgo, aired >= 1, aired <= newWithinDays {
            return .newEpisode
        }
        if input.seriesIsComplete == true {
            return .allEpisodesAvailable
        }
        if let added = input.addedDaysAgo, added >= 0, added <= recentlyAddedWithinDays {
            return .recentlyAdded
        }
        return nil
    }

    // MARK: - Date helpers (shared with callers)

    /// Whole days between an event and a reference date (>= 0 in the past).
    static func daysAgo(from event: Date?, reference: Date) -> Int? {
        guard let event else { return nil }
        return Int(reference.timeIntervalSince(event) / 86_400)
    }

    /// Parses Plex `originallyAvailableAt` ("yyyy-MM-dd") to a UTC Date.
    static func parseAirDate(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: String(raw.prefix(10)))
    }

    /// Plex `addedAt` epoch seconds → Date.
    static func addedDate(fromEpoch epoch: Int?) -> Date? {
        guard let epoch, epoch > 0 else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(epoch))
    }
}

// MARK: - Placement rules

/// Where a status label may appear. Status labels are editorial guidance, not
/// per-card clutter, so each surface allows only the labels that make sense for
/// the thing it represents.
nonisolated enum ContentStatusSurface: Sendable, Equatable {
    /// Home hero — the PRIMARY consumer (show/movie level, editorial).
    case hero
    /// Detail page header (show/movie level).
    case detail
    /// Episode card (per-episode signals only).
    case episodeCard
    /// Landscape/poster shelves — intentionally none (avoid noise).
    case shelf
}

nonisolated enum ContentStatusPlacement {
    /// Whether `label` is allowed on `surface`. Show/movie-level editorial labels
    /// belong on hero/detail; per-episode labels belong on episode cards; shelves
    /// stay clean.
    static func allows(_ label: ContentStatusLabel, on surface: ContentStatusSurface) -> Bool {
        switch surface {
        case .hero, .detail:
            switch label {
            // Editorial / show-level — yes.
            case .premieres, .returns, .newSeason, .newEpisodeWeekly, .comingSoon,
                 .allEpisodesAvailable, .recentlyAdded:
                return true
            // Per-episode — not at show/movie level.
            case .seasonFinale, .episodeAvailableToday, .newEpisode:
                return false
            }
        case .episodeCard:
            switch label {
            case .seasonFinale, .episodeAvailableToday, .newEpisode:
                return true
            default:
                return false
            }
        case .shelf:
            // Shelves show no status labels — the row title already provides
            // context ("Recently Added", etc.) and per-card chips read as noise.
            return false
        }
    }
}
