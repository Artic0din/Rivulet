//
//  EpisodePresentationPolicyTests.swift
//  RivuletTests
//
//  E3-PR10 / ADO-03 — episode card presentation + content status label system.
//

import XCTest
@testable import Rivulet

final class EpisodeCardPresentationTests: XCTestCase {

    func testEpisodeLabel() {
        XCTAssertEqual(EpisodeCardPresentation.episodeLabel(index: 13), "EPISODE 13")
        XCTAssertEqual(EpisodeCardPresentation.episodeLabel(index: nil), "EPISODE")
    }

    // ADO-01B: the model-based `model(...)`/`EpisodeCardModel`/`accessibilityLabel(_:)`
    // tests were retired alongside the dead `EpisodeContentCard` view. The live
    // surface is `episodeLabel(index:)` + the resolved-values overload below.

    func testResolvedAccessibilityLabel() {
        XCTAssertEqual(
            EpisodeCardPresentation.accessibilityLabel(episodeLabel: "EPISODE 13", title: "Be Still My Heart", runtime: "40m", isWatched: false, progress: nil),
            "Episode 13, Be Still My Heart, 40m"
        )
    }

    func testResolvedAccessibilityLabelInProgress() {
        XCTAssertEqual(
            EpisodeCardPresentation.accessibilityLabel(episodeLabel: "EPISODE 2", title: "Pilot", runtime: "47m", isWatched: false, progress: 0.5),
            "Episode 2, Pilot, 47m, 50 percent watched"
        )
    }

    func testResolvedAccessibilityLabelWithSeasonPrefixAndWatched() {
        // `.capitalized` segments "S06E13" on the digit boundary, keeping both
        // letter groups capitalised.
        XCTAssertEqual(
            EpisodeCardPresentation.accessibilityLabel(episodeLabel: "S06E13", title: "Be Still My Heart", runtime: "40m", isWatched: true, progress: nil),
            "S06E13, Be Still My Heart, 40m, Watched"
        )
    }

    // ADO-05: the spoken label includes the status only when one is visible,
    // and in a sensible order (number → title → status → runtime → state).
    func testAccessibilityLabelIncludesVisibleStatus() {
        XCTAssertEqual(
            EpisodeCardPresentation.accessibilityLabel(
                episodeLabel: "EPISODE 10", title: "The Finale",
                statusLabel: .seasonFinale, runtime: "55m", isWatched: false, progress: nil
            ),
            "Episode 10, The Finale, Season Finale, 55m"
        )
    }

    func testAccessibilityLabelOmitsHiddenStatus() {
        // No visible status → nothing extra is announced (unchanged behaviour).
        XCTAssertEqual(
            EpisodeCardPresentation.accessibilityLabel(
                episodeLabel: "EPISODE 3", title: "Pilot",
                statusLabel: nil, runtime: "47m", isWatched: false, progress: nil
            ),
            "Episode 3, Pilot, 47m"
        )
    }
}

// MARK: - ADO-05: episode-card content-status label (Plex-backed, pure)

final class EpisodeCardStatusLabelTests: XCTestCase {

    /// Fixed reference day so air-date deltas are deterministic. parseAirDate
    /// yields UTC midnight, matching how the mapper parses `originallyAvailableAt`.
    private let ref = ContentStatusPolicy.parseAirDate("2026-06-01")!

    private func label(
        episodeIndex: Int?,
        seasonNumber: Int?,
        seasonEpisodeCount: Int?,
        air: String? = nil
    ) -> ContentStatusLabel? {
        EpisodeCardPresentation.episodeStatusLabel(
            episodeIndex: episodeIndex,
            seasonNumber: seasonNumber,
            seasonEpisodeCount: seasonEpisodeCount,
            airDate: ContentStatusPolicy.parseAirDate(air),
            reference: ref
        )
    }

    // MARK: Season finale

    func testSeasonFinaleForFinalEpisodeOfNormalSeason() {
        XCTAssertEqual(label(episodeIndex: 10, seasonNumber: 3, seasonEpisodeCount: 10), .seasonFinale)
    }

    func testNoSeasonFinaleForNonFinalEpisode() {
        XCTAssertNil(label(episodeIndex: 9, seasonNumber: 3, seasonEpisodeCount: 10))
    }

    func testNoSeasonFinaleForSeasonZeroSpecial() {
        // Would be a finale (index == count) if it were a regular season — the
        // specials guard must suppress it.
        XCTAssertNil(label(episodeIndex: 8, seasonNumber: 0, seasonEpisodeCount: 8))
    }

    func testNoSeasonFinaleWhenSeasonIndexMissing() {
        XCTAssertNil(label(episodeIndex: 10, seasonNumber: nil, seasonEpisodeCount: 10))
    }

    func testNoSeasonFinaleWhenEpisodeIndexMissing() {
        XCTAssertNil(label(episodeIndex: nil, seasonNumber: 3, seasonEpisodeCount: 10))
    }

    func testNoSeasonFinaleWhenSeasonCountMissing() {
        XCTAssertNil(label(episodeIndex: 10, seasonNumber: 3, seasonEpisodeCount: nil))
    }

    // MARK: Aired today / new episode (non-finale episodes)

    func testAiredTodayForTodaysValidAirDate() {
        XCTAssertEqual(
            label(episodeIndex: 1, seasonNumber: 1, seasonEpisodeCount: 10, air: "2026-06-01"),
            .episodeAvailableToday
        )
    }

    func testNewEpisodeForRecentValidAirDate() {
        XCTAssertEqual(
            label(episodeIndex: 1, seasonNumber: 1, seasonEpisodeCount: 10, air: "2026-05-27"),
            .newEpisode
        )
    }

    func testStaleAirDateProducesNoCurrentStatus() {
        // Aired long ago, not a finale → no episode-card label (Recently Added is
        // intentionally not permitted on episode cards).
        XCTAssertNil(label(episodeIndex: 4, seasonNumber: 2, seasonEpisodeCount: 10, air: "2025-11-01"))
    }

    func testFutureAirDateProducesNoTodayOrNewEpisode() {
        XCTAssertNil(label(episodeIndex: 1, seasonNumber: 1, seasonEpisodeCount: 10, air: "2026-06-04"))
    }

    func testFinaleTakesPrecedenceOverRecentAirDate() {
        // A recently-aired finale reads as the finale, not "New Episode".
        XCTAssertEqual(
            label(episodeIndex: 10, seasonNumber: 3, seasonEpisodeCount: 10, air: "2026-05-27"),
            .seasonFinale
        )
    }

    func testNoLabelWhenNothingApplies() {
        XCTAssertNil(label(episodeIndex: 5, seasonNumber: 2, seasonEpisodeCount: 10))
    }
}
