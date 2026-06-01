//
//  DetailMetadataCascadeTests.swift
//  RivuletTests
//
//  E3-PR4 — deterministic detail metadata cascade ordering.
//

import XCTest
@testable import Rivulet

final class DetailMetadataCascadeTests: XCTestCase {

    // MARK: - primaryParts

    func testMovieTypeLabelThenGenres() {
        let parts = DetailMetadataCascade.primaryParts(kind: .movie, genres: ["Action", "Sci-Fi", "Thriller"])
        XCTAssertEqual(parts, ["Movie", "Action", "Sci-Fi"]) // type + 2 genres
    }

    func testShowSeasonEpisodeAllMapToTVShow() {
        for kind in [MediaKind.show, .season, .episode] {
            let parts = DetailMetadataCascade.primaryParts(kind: kind, genres: ["Drama"])
            XCTAssertEqual(parts.first, "TV Show", "\(kind) should label as TV Show")
        }
    }

    func testNonTitleKindsOmitTypeLabel() {
        for kind in [MediaKind.collection, .person, .unknown] {
            let parts = DetailMetadataCascade.primaryParts(kind: kind, genres: ["Drama"])
            XCTAssertEqual(parts, ["Drama"], "\(kind) should have no type label")
        }
    }

    func testGenreCapRespected() {
        let parts = DetailMetadataCascade.primaryParts(kind: .movie, genres: ["A", "B", "C", "D"], maxGenres: 2)
        XCTAssertEqual(parts, ["Movie", "A", "B"])
    }

    func testZeroGenreCap() {
        let parts = DetailMetadataCascade.primaryParts(kind: .movie, genres: ["A", "B"], maxGenres: 0)
        XCTAssertEqual(parts, ["Movie"])
    }

    func testNoGenres() {
        XCTAssertEqual(DetailMetadataCascade.primaryParts(kind: .movie, genres: []), ["Movie"])
    }

    // MARK: - chronologyParts

    func testYearThenDuration() {
        XCTAssertEqual(DetailMetadataCascade.chronologyParts(year: 2024, duration: "1h 47m"), ["2024", "1h 47m"])
    }

    func testYearOnly() {
        XCTAssertEqual(DetailMetadataCascade.chronologyParts(year: 2024, duration: nil), ["2024"])
    }

    func testDurationOnly() {
        XCTAssertEqual(DetailMetadataCascade.chronologyParts(year: nil, duration: "49 min"), ["49 min"])
    }

    func testNeither() {
        XCTAssertTrue(DetailMetadataCascade.chronologyParts(year: nil, duration: nil).isEmpty)
    }

    func testOrderIsStableYearFirst() {
        // Year must always precede duration when both present.
        let parts = DetailMetadataCascade.chronologyParts(year: 1999, duration: "2h")
        XCTAssertEqual(parts.firstIndex(of: "1999"), 0)
        XCTAssertEqual(parts.firstIndex(of: "2h"), 1)
    }
}
