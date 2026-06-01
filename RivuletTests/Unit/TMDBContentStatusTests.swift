//
//  TMDBContentStatusTests.swift
//  RivuletTests
//
//  ADO-04 — TMDb status decode + mapping into ContentStatusInput, then through
//  ContentStatusPolicy. Reference date fixed for determinism.
//

import XCTest
@testable import Rivulet

final class TMDBContentStatusTests: XCTestCase {

    private let ref = ContentStatusPolicy.parseAirDate("2026-06-01")!
    private let future = "2026-08-01"
    private let past = "2026-01-01"

    // MARK: - Decoding (incl. nested next_episode_to_air + seasons[])

    func testDecodesTVStatusPayload() throws {
        let json = """
        {
          "status": "Returning Series",
          "in_production": true,
          "first_air_date": "2019-04-01",
          "last_air_date": "2026-01-01",
          "number_of_seasons": 5,
          "number_of_episodes": 50,
          "next_episode_to_air": { "air_date": "2026-08-01", "season_number": 5, "episode_number": 3 },
          "last_episode_to_air": { "air_date": "2026-01-01", "season_number": 4, "episode_number": 10 },
          "seasons": [
            { "air_date": "2019-04-01", "episode_count": 10, "season_number": 1 },
            { "air_date": "2026-08-01", "episode_count": 8, "season_number": 5 }
          ]
        }
        """.data(using: .utf8)!
        let d = try JSONDecoder().decode(TMDBStatusDetail.self, from: json)
        XCTAssertEqual(d.status, "Returning Series")
        XCTAssertEqual(d.inProduction, true)
        XCTAssertEqual(d.numberOfSeasons, 5)
        XCTAssertEqual(d.nextEpisodeToAir?.airDate, "2026-08-01")
        XCTAssertEqual(d.nextEpisodeToAir?.episodeNumber, 3)
        XCTAssertEqual(d.seasons?.count, 2)
        XCTAssertEqual(d.seasons?.last?.airDate, "2026-08-01")
    }

    func testDecodesMoviePayloadAndToleratesMissingFields() throws {
        let json = """
        { "status": "Released", "release_date": "2024-03-01" }
        """.data(using: .utf8)!
        let d = try JSONDecoder().decode(TMDBStatusDetail.self, from: json)
        XCTAssertEqual(d.status, "Released")
        XCTAssertEqual(d.releaseDate, "2024-03-01")
        XCTAssertNil(d.nextEpisodeToAir)
        XCTAssertNil(d.seasons)
    }

    func testDecodesEmptyObject() throws {
        let d = try JSONDecoder().decode(TMDBStatusDetail.self, from: "{}".data(using: .utf8)!)
        XCTAssertNil(d.status)
        XCTAssertNil(d.nextEpisodeToAir)
    }

    // MARK: - Mapping → ContentStatusInput → classify

    private func classify(_ detail: TMDBStatusDetail, kind: ContentStatusKind) -> ContentStatusLabel? {
        ContentStatusPolicy.classify(TMDBContentStatus.input(from: detail, kind: kind, reference: ref), reference: ref)
    }

    func testReturningAfterLongBreakReturns() {
        // Large gap (months) since the last episode → "Returns <date>".
        let d = TMDBStatusDetail(
            status: "Returning Series", lastAirDate: past,
            nextEpisodeToAir: .init(airDate: future, seasonNumber: 5, episodeNumber: 3)
        )
        XCTAssertEqual(classify(d, kind: .show), .returns(ContentStatusPolicy.parseAirDate(future)!))
    }

    func testActivelyAiringWeeklyShowShowsWeeklyCadence() {
        // Last episode ~1 week before the upcoming one → "New Episode Every <day>".
        let last = "2026-06-04"   // after ref (2026-06-01) is fine; gap is last→next
        let next = "2026-06-11"   // Thursday, 7 days later, mid-season
        let d = TMDBStatusDetail(
            status: "Returning Series",
            nextEpisodeToAir: .init(airDate: next, seasonNumber: 5, episodeNumber: 5),
            lastEpisodeToAir: .init(airDate: last, seasonNumber: 5, episodeNumber: 4)
        )
        let label = classify(d, kind: .show)
        guard case .newEpisodeWeekly = label else {
            return XCTFail("expected weekly cadence, got \(String(describing: label))")
        }
    }

    func testStaleNextEpisodeProducesNoWeeklyLabel() {
        // Next episode already in the past → neither weekly nor returns.
        let d = TMDBStatusDetail(
            status: "Returning Series", lastAirDate: "2025-12-01",
            nextEpisodeToAir: .init(airDate: "2025-12-08", seasonNumber: 5, episodeNumber: 5)
        )
        XCTAssertNil(classify(d, kind: .show))
    }

    func testSeasonZeroSpecialDoesNotReadAsNewSeason() {
        // A special (season 0, ep 1) must NOT be labelled a new season.
        let d = TMDBStatusDetail(
            status: "Returning Series", lastAirDate: past,
            nextEpisodeToAir: .init(airDate: future, seasonNumber: 0, episodeNumber: 1)
        )
        XCTAssertNotEqual(classify(d, kind: .show), .newSeason(ContentStatusPolicy.parseAirDate(future)!))
    }

    func testUpcomingSeasonPremiereIsNewSeason() {
        let d = TMDBStatusDetail(
            status: "Returning Series", lastAirDate: past,
            nextEpisodeToAir: .init(airDate: future, seasonNumber: 6, episodeNumber: 1)
        )
        XCTAssertEqual(classify(d, kind: .show), .newSeason(ContentStatusPolicy.parseAirDate(future)!))
    }

    func testNotYetAiredSeriesPremieres() {
        let d = TMDBStatusDetail(status: "Returning Series", firstAirDate: future)
        XCTAssertEqual(classify(d, kind: .show), .premieres(ContentStatusPolicy.parseAirDate(future)!))
    }

    func testEndedSeriesIsAllEpisodesAvailable() {
        let d = TMDBStatusDetail(status: "Ended", inProduction: false, lastAirDate: past)
        XCTAssertEqual(classify(d, kind: .show), .allEpisodesAvailable)
    }

    func testStaleUpcomingEpisodeProducesNoLabel() {
        // next episode air date is in the PAST relative to the reference → not upcoming.
        let d = TMDBStatusDetail(
            status: "Returning Series", lastAirDate: past,
            nextEpisodeToAir: .init(airDate: past, seasonNumber: 5, episodeNumber: 3)
        )
        XCTAssertNil(classify(d, kind: .show))
    }

    func testUnreleasedMovieIsComingSoon() {
        let d = TMDBStatusDetail(status: "Post Production", releaseDate: future)
        XCTAssertEqual(classify(d, kind: .movie), .comingSoon(ContentStatusPolicy.parseAirDate(future)!))
    }

    func testReleasedMovieHasNoLabel() {
        let d = TMDBStatusDetail(status: "Released", releaseDate: past)
        XCTAssertNil(classify(d, kind: .movie))
    }

    func testReturningSeriesWithNoUpcomingEpisodeHasNoLabel() {
        let d = TMDBStatusDetail(status: "Returning Series", lastAirDate: past)
        XCTAssertNil(classify(d, kind: .show))
    }

    // MARK: - Kind mapping

    func testKindFromPlexType() {
        XCTAssertEqual(TMDBContentStatus.kind(fromPlexType: "movie"), .movie)
        XCTAssertEqual(TMDBContentStatus.kind(fromPlexType: "show"), .show)
        XCTAssertEqual(TMDBContentStatus.kind(fromPlexType: "episode"), .episode)
        XCTAssertEqual(TMDBContentStatus.kind(fromPlexType: nil), .movie)
    }
}
