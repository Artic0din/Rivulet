//
//  HomeRowOrderingPolicyTests.swift
//  RivuletTests
//
//  E2-PR5 — Continue Watching is always the most prominent content row.
//

import XCTest
@testable import Rivulet

final class HomeRowOrderingPolicyTests: XCTestCase {

    private func hub(_ id: String, itemCount: Int) throws -> PlexHub {
        let meta = (0..<itemCount).map { "{ \"ratingKey\": \"\(id)-\($0)\" }" }.joined(separator: ",")
        let json = "{ \"hubIdentifier\": \"\(id)\", \"title\": \"\(id)\", \"Metadata\": [\(meta)] }".data(using: .utf8)!
        return try JSONDecoder().decode(PlexHub.self, from: json)
    }

    func testContinueWatchingPinnedFirst() throws {
        let cw = try hub("continueWatching", itemCount: 2)
        let rows = [try hub("recentlyAddedMovies", itemCount: 5), try hub("recentlyAddedTV", itemCount: 5)]
        let result = HomeRowOrderingPolicy.order(continueWatching: cw, followingRows: rows)
        XCTAssertEqual(result.map { $0.hubIdentifier }, ["continueWatching", "recentlyAddedMovies", "recentlyAddedTV"])
    }

    func testContinueWatchingOmittedWhenNil() throws {
        let rows = [try hub("recentlyAddedMovies", itemCount: 5)]
        let result = HomeRowOrderingPolicy.order(continueWatching: nil, followingRows: rows)
        XCTAssertEqual(result.map { $0.hubIdentifier }, ["recentlyAddedMovies"])
    }

    func testContinueWatchingOmittedWhenEmpty() throws {
        let cw = try hub("continueWatching", itemCount: 0)
        let rows = [try hub("recentlyAddedMovies", itemCount: 5)]
        let result = HomeRowOrderingPolicy.order(continueWatching: cw, followingRows: rows)
        XCTAssertEqual(result.map { $0.hubIdentifier }, ["recentlyAddedMovies"])
    }

    func testFollowingOrderPreserved() throws {
        let rows = [try hub("a", itemCount: 1), try hub("b", itemCount: 1), try hub("c", itemCount: 1)]
        let result = HomeRowOrderingPolicy.order(continueWatching: nil, followingRows: rows)
        XCTAssertEqual(result.map { $0.hubIdentifier }, ["a", "b", "c"])
    }

    func testEmptyWhenNothing() {
        XCTAssertTrue(HomeRowOrderingPolicy.order(continueWatching: nil, followingRows: []).isEmpty)
    }
}
