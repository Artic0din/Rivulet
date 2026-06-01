//
//  ContentStatusPolicyTests.swift
//  RivuletTests
//
//  ADO-03 — Content Status Label System: classification, dates, placement.
//

import XCTest
@testable import Rivulet

final class ContentStatusPolicyTests: XCTestCase {

    private let ref = ContentStatusPolicy.parseAirDate("2026-06-01")!

    // MARK: - Current-content classification (Plex-backed)

    func testSeasonFinaleWhenLastEpisode() {
        let label = ContentStatusPolicy.classify(
            .init(kind: .episode, episodeIndex: 10, seasonEpisodeCount: 10), reference: ref
        )
        XCTAssertEqual(label, .seasonFinale)
    }

    func testNotFinaleMidSeason() {
        let label = ContentStatusPolicy.classify(
            .init(kind: .episode, episodeIndex: 4, seasonEpisodeCount: 10), reference: ref
        )
        XCTAssertNotEqual(label, .seasonFinale)
    }

    func testEpisodeAvailableTodayWhenAiredZeroDaysAgo() {
        let label = ContentStatusPolicy.classify(.init(kind: .episode, airedDaysAgo: 0), reference: ref)
        XCTAssertEqual(label, .episodeAvailableToday)
    }

    func testNewEpisodeWithinWindow() {
        XCTAssertEqual(ContentStatusPolicy.classify(.init(kind: .episode, airedDaysAgo: 3), reference: ref), .newEpisode)
        XCTAssertEqual(ContentStatusPolicy.classify(.init(kind: .episode, airedDaysAgo: 14), reference: ref), .newEpisode)
    }

    func testNoNewEpisodeWhenOld() {
        XCTAssertNil(ContentStatusPolicy.classify(.init(kind: .episode, airedDaysAgo: 60), reference: ref))
    }

    func testRecentlyAddedWhenAddedRecentlyButOld() {
        let label = ContentStatusPolicy.classify(
            .init(kind: .movie, airedDaysAgo: 400, addedDaysAgo: 5), reference: ref
        )
        XCTAssertEqual(label, .recentlyAdded)
    }

    func testAllEpisodesAvailableWhenComplete() {
        let label = ContentStatusPolicy.classify(.init(kind: .show, seriesIsComplete: true), reference: ref)
        XCTAssertEqual(label, .allEpisodesAvailable)
    }

    func testNoLabelWhenInsufficientData() {
        XCTAssertNil(ContentStatusPolicy.classify(.init(kind: .movie), reference: ref))
    }

    func testNegativeAiredDaysProducesNoCurrentLabel() {
        // A future air date (negative days ago) must not read as "new"/today.
        XCTAssertNil(ContentStatusPolicy.classify(.init(kind: .episode, airedDaysAgo: -5), reference: ref))
    }

    // MARK: - Future-facing classification (TMDb-gated; supplied dates)

    func testPremieresWhenFutureDate() {
        let future = ref.addingTimeInterval(3 * 86_400)
        let label = ContentStatusPolicy.classify(.init(kind: .show, premiereDate: future), reference: ref)
        XCTAssertEqual(label, .premieres(future))
    }

    func testReturnsWhenFutureDate() {
        let future = ref.addingTimeInterval(20 * 86_400)
        let label = ContentStatusPolicy.classify(.init(kind: .show, returnDate: future), reference: ref)
        XCTAssertEqual(label, .returns(future))
    }

    func testFutureDateInPastDoesNotFire() {
        // A premiere date already in the past is stale → not surfaced as upcoming.
        let past = ref.addingTimeInterval(-10 * 86_400)
        let label = ContentStatusPolicy.classify(.init(kind: .show, premiereDate: past), reference: ref)
        XCTAssertNil(label)
    }

    func testFutureEventOutranksCurrentSignals() {
        let future = ref.addingTimeInterval(5 * 86_400)
        // Even with a recently-added signal, an upcoming premiere wins.
        let label = ContentStatusPolicy.classify(
            .init(kind: .show, addedDaysAgo: 2, premiereDate: future), reference: ref
        )
        XCTAssertEqual(label, .premieres(future))
    }

    func testWeeklyCadenceLabel() {
        let label = ContentStatusPolicy.classify(.init(kind: .show, weeklyReleaseDay: .friday), reference: ref)
        XCTAssertEqual(label, .newEpisodeWeekly(.friday))
    }

    // MARK: - Display text

    func testDisplayTextCurrentLabels() {
        XCTAssertEqual(ContentStatusLabel.seasonFinale.displayText, "Season Finale")
        XCTAssertEqual(ContentStatusLabel.episodeAvailableToday.displayText, "New Episode Today")
        XCTAssertEqual(ContentStatusLabel.newEpisode.displayText, "New Episode")
        XCTAssertEqual(ContentStatusLabel.allEpisodesAvailable.displayText, "All Episodes Available")
        XCTAssertEqual(ContentStatusLabel.recentlyAdded.displayText, "Recently Added")
        XCTAssertEqual(ContentStatusLabel.newEpisodeWeekly(.friday).displayText, "New Episode Every Friday")
    }

    func testDisplayTextDatedLabelsHavePrefix() {
        let d = ref
        XCTAssertTrue(ContentStatusLabel.premieres(d).displayText.hasPrefix("Premieres "))
        XCTAssertTrue(ContentStatusLabel.returns(d).displayText.hasPrefix("Returns "))
        XCTAssertTrue(ContentStatusLabel.newSeason(d).displayText.hasPrefix("New Season "))
        XCTAssertTrue(ContentStatusLabel.comingSoon(d).displayText.hasPrefix("Coming "))
    }

    func testDatedLabelsShowSpecificDayNotMonthYear() {
        // A concrete date renders as "dd MMMM" (e.g. "06 August"), never "MMM yyyy".
        let date = ContentStatusPolicy.parseAirDate("2026-08-06")!
        XCTAssertEqual(ContentStatusLabel.newSeason(date).displayText, "New Season 06 August")
        XCTAssertEqual(ContentStatusLabel.premieres(date).displayText, "Premieres 06 August")
    }

    func testIsFutureFacingFlag() {
        XCTAssertTrue(ContentStatusLabel.premieres(ref).isFutureFacing)
        XCTAssertTrue(ContentStatusLabel.newEpisodeWeekly(.monday).isFutureFacing)
        XCTAssertFalse(ContentStatusLabel.seasonFinale.isFutureFacing)
        XCTAssertFalse(ContentStatusLabel.recentlyAdded.isFutureFacing)
    }

    // MARK: - Date helpers

    func testParseAirDateAndDaysAgo() {
        let aired = ContentStatusPolicy.parseAirDate("2024-01-01")
        XCTAssertNotNil(aired)
        let reference = ContentStatusPolicy.parseAirDate("2024-01-11")!
        XCTAssertEqual(ContentStatusPolicy.daysAgo(from: aired, reference: reference), 10)
        XCTAssertNil(ContentStatusPolicy.parseAirDate(nil))
        XCTAssertNil(ContentStatusPolicy.parseAirDate(""))
    }

    func testAddedDateFromEpoch() {
        XCTAssertNotNil(ContentStatusPolicy.addedDate(fromEpoch: 1_700_000_000))
        XCTAssertNil(ContentStatusPolicy.addedDate(fromEpoch: 0))
        XCTAssertNil(ContentStatusPolicy.addedDate(fromEpoch: nil))
    }

    // MARK: - Placement rules

    func testHeroAllowsEditorialAndShowLevelOnly() {
        XCTAssertTrue(ContentStatusPlacement.allows(.premieres(ref), on: .hero))
        XCTAssertTrue(ContentStatusPlacement.allows(.recentlyAdded, on: .hero))
        XCTAssertTrue(ContentStatusPlacement.allows(.allEpisodesAvailable, on: .hero))
        // Per-episode labels do not belong on the show/movie-level hero.
        XCTAssertFalse(ContentStatusPlacement.allows(.seasonFinale, on: .hero))
        XCTAssertFalse(ContentStatusPlacement.allows(.newEpisode, on: .hero))
    }

    func testDetailMatchesHeroLevel() {
        XCTAssertTrue(ContentStatusPlacement.allows(.returns(ref), on: .detail))
        XCTAssertFalse(ContentStatusPlacement.allows(.seasonFinale, on: .detail))
    }

    func testEpisodeCardAllowsPerEpisodeOnly() {
        XCTAssertTrue(ContentStatusPlacement.allows(.seasonFinale, on: .episodeCard))
        XCTAssertTrue(ContentStatusPlacement.allows(.episodeAvailableToday, on: .episodeCard))
        XCTAssertTrue(ContentStatusPlacement.allows(.newEpisode, on: .episodeCard))
        XCTAssertFalse(ContentStatusPlacement.allows(.recentlyAdded, on: .episodeCard))
        XCTAssertFalse(ContentStatusPlacement.allows(.premieres(ref), on: .episodeCard))
    }

    func testShelfShowsNoStatusLabels() {
        XCTAssertFalse(ContentStatusPlacement.allows(.recentlyAdded, on: .shelf))
        XCTAssertFalse(ContentStatusPlacement.allows(.seasonFinale, on: .shelf))
        XCTAssertFalse(ContentStatusPlacement.allows(.premieres(ref), on: .shelf))
    }
}
