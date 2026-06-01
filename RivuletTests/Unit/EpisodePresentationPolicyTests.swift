//
//  EpisodePresentationPolicyTests.swift
//  RivuletTests
//
//  E3-PR10 — schedule labels + episode card presentation.
//

import XCTest
@testable import Rivulet

final class ScheduleLabelPolicyTests: XCTestCase {

    private func input(
        aired: Int? = nil, added: Int? = nil, idx: Int? = nil, count: Int? = nil, inProgress: Bool = false
    ) -> ScheduleLabelPolicy.Input {
        .init(airedDaysAgo: aired, addedDaysAgo: added, episodeIndex: idx, seasonEpisodeCount: count, isInProgress: inProgress)
    }

    func testSeasonFinaleWinsOverEverything() {
        XCTAssertEqual(ScheduleLabelPolicy.label(for: input(aired: 0, added: 0, idx: 10, count: 10, inProgress: true)), .seasonFinale)
    }

    func testNewWhenRecentlyAired() {
        XCTAssertEqual(ScheduleLabelPolicy.label(for: input(aired: 3)), .new)
        XCTAssertEqual(ScheduleLabelPolicy.label(for: input(aired: 14)), .new)
    }

    func testNotNewWhenOld() {
        XCTAssertNil(ScheduleLabelPolicy.label(for: input(aired: 60)))
    }

    func testRecentlyAddedWhenAddedRecentlyButOld() {
        XCTAssertEqual(ScheduleLabelPolicy.label(for: input(aired: 400, added: 5)), .recentlyAdded)
    }

    func testContinueWatchingLowestPriority() {
        XCTAssertEqual(ScheduleLabelPolicy.label(for: input(inProgress: true)), .continueWatching)
    }

    func testNoLabelWhenInsufficientData() {
        XCTAssertNil(ScheduleLabelPolicy.label(for: input()))
    }

    func testNegativeDaysIgnored() {
        // A future air date (negative days ago) should not be "New".
        XCTAssertNil(ScheduleLabelPolicy.label(for: input(aired: -5)))
    }

    func testDisplayText() {
        XCTAssertEqual(ScheduleLabel.new.displayText, "New")
        XCTAssertEqual(ScheduleLabel.seasonFinale.displayText, "Season Finale")
        XCTAssertEqual(ScheduleLabel.recentlyAdded.displayText, "Recently Added")
    }

    func testParseAirDateAndDaysAgo() {
        let aired = ScheduleLabelPolicy.parseAirDate("2024-01-01")
        XCTAssertNotNil(aired)
        let ref = ScheduleLabelPolicy.parseAirDate("2024-01-11")!
        XCTAssertEqual(ScheduleLabelPolicy.daysAgo(from: aired, reference: ref), 10)
        XCTAssertNil(ScheduleLabelPolicy.parseAirDate(nil))
        XCTAssertNil(ScheduleLabelPolicy.parseAirDate(""))
    }
}

final class EpisodeCardPresentationTests: XCTestCase {

    func testEpisodeLabel() {
        XCTAssertEqual(EpisodeCardPresentation.episodeLabel(index: 13), "EPISODE 13")
        XCTAssertEqual(EpisodeCardPresentation.episodeLabel(index: nil), "EPISODE")
    }

    func testModelRuntimeAndProgress() {
        let m = EpisodeCardPresentation.model(
            index: 13, title: "Be Still My Heart", summary: "  A synopsis.  ",
            durationMs: 2_400_000, viewOffsetMs: 840_000, isWatched: false
        )
        XCTAssertEqual(m.episodeLabel, "EPISODE 13")
        XCTAssertEqual(m.title, "Be Still My Heart")
        XCTAssertEqual(m.synopsis, "A synopsis.")
        XCTAssertEqual(m.runtime, "40m")            // 2_400_000ms = 40min
        XCTAssertEqual(m.progress!, 0.35, accuracy: 0.001)
        XCTAssertFalse(m.isWatched)
    }

    func testNoProgressWhenNotStartedOrFinished() {
        XCTAssertNil(EpisodeCardPresentation.model(index: 1, title: "x", summary: nil, durationMs: 1000, viewOffsetMs: 0, isWatched: false).progress)
        XCTAssertNil(EpisodeCardPresentation.model(index: 1, title: "x", summary: nil, durationMs: 1000, viewOffsetMs: 1000, isWatched: true).progress)
        XCTAssertNil(EpisodeCardPresentation.model(index: 1, title: "x", summary: nil, durationMs: nil, viewOffsetMs: nil, isWatched: false).progress)
    }

    func testMissingTitleAndSynopsisFallback() {
        let m = EpisodeCardPresentation.model(index: nil, title: nil, summary: "   ", durationMs: nil, viewOffsetMs: nil, isWatched: false)
        XCTAssertEqual(m.title, "Episode")
        XCTAssertNil(m.synopsis)
        XCTAssertNil(m.runtime)
    }

    func testAccessibilityLabelWatched() {
        let m = EpisodeCardModel(episodeLabel: "EPISODE 13", title: "Be Still My Heart", synopsis: nil, runtime: "40m", progress: nil, isWatched: true)
        XCTAssertEqual(EpisodeCardPresentation.accessibilityLabel(m), "Episode 13, Be Still My Heart, 40m, Watched")
    }

    func testAccessibilityLabelInProgress() {
        let m = EpisodeCardModel(episodeLabel: "EPISODE 2", title: "Pilot", synopsis: nil, runtime: "47m", progress: 0.5, isWatched: false)
        XCTAssertEqual(EpisodeCardPresentation.accessibilityLabel(m), "Episode 2, Pilot, 47m, 50 percent watched")
    }

    // Resolved-values overload (used by the live EpisodeCard, ADO-01).
    func testResolvedAccessibilityLabel() {
        XCTAssertEqual(
            EpisodeCardPresentation.accessibilityLabel(episodeLabel: "EPISODE 13", title: "Be Still My Heart", runtime: "40m", isWatched: false, progress: nil),
            "Episode 13, Be Still My Heart, 40m"
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

    func testResolvedAccessibilityLabelMatchesModelOverload() {
        let m = EpisodeCardModel(episodeLabel: "EPISODE 5", title: "X", synopsis: nil, runtime: "30m", progress: 0.25, isWatched: false)
        XCTAssertEqual(
            EpisodeCardPresentation.accessibilityLabel(m),
            EpisodeCardPresentation.accessibilityLabel(episodeLabel: "EPISODE 5", title: "X", runtime: "30m", isWatched: false, progress: 0.25)
        )
    }
}
