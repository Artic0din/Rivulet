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
}
