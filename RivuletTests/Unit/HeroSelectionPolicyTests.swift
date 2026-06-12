//
//  HeroSelectionPolicyTests.swift
//  RivuletTests
//
//  E2-PR4 — deterministic hero selection: Continue Watching first, then
//  curated, then recently added, then any other; stale/identity-less items
//  filtered; never empty when usable content exists.
//

import XCTest
@testable import Rivulet

final class HeroSelectionPolicyTests: XCTestCase {

    private func item(_ ratingKey: String?, title: String = "T") throws -> PlexMetadata {
        let keyField = ratingKey.map { "\"ratingKey\": \"\($0)\"," } ?? ""
        let json = "{ \(keyField) \"title\": \"\(title)\", \"type\": \"movie\" }".data(using: .utf8)!
        return try JSONDecoder().decode(PlexMetadata.self, from: json)
    }

    private func candidate(_ kind: HeroHubKind, _ keys: [String?]) throws -> HeroHubCandidate {
        HeroHubCandidate(kind: kind, identifier: "\(kind)", items: try keys.map { try item($0) })
    }

    // MARK: - Priority

    func testContinueWatchingWinsOverEverything() throws {
        let candidates = [
            try candidate(.recentlyAdded, ["ra1", "ra2"]),
            try candidate(.curated, ["c1"]),
            try candidate(.continueWatching, ["cw1", "cw2"]),
        ]
        let result = HeroSelectionPolicy.select(from: candidates, cap: 9)
        XCTAssertEqual(result.compactMap { $0.ratingKey }, ["cw1", "cw2"])
    }

    func testCuratedWinsWhenNoContinueWatching() throws {
        let candidates = [
            try candidate(.recentlyAdded, ["ra1"]),
            try candidate(.curated, ["c1", "c2"]),
            try candidate(.other, ["o1"]),
        ]
        XCTAssertEqual(HeroSelectionPolicy.select(from: candidates, cap: 9).compactMap { $0.ratingKey }, ["c1", "c2"])
    }

    func testRecentlyAddedWinsWhenNoCWorCurated() throws {
        let candidates = [
            try candidate(.other, ["o1"]),
            try candidate(.recentlyAdded, ["ra1", "ra2"]),
        ]
        XCTAssertEqual(HeroSelectionPolicy.select(from: candidates, cap: 9).compactMap { $0.ratingKey }, ["ra1", "ra2"])
    }

    func testOtherFallbackPreservesOrderWhenNoPrioritisedKinds() throws {
        let candidates = [
            try candidate(.other, ["first"]),
            try candidate(.other, ["second"]),
        ]
        XCTAssertEqual(HeroSelectionPolicy.select(from: candidates, cap: 9).compactMap { $0.ratingKey }, ["first"])
    }

    // MARK: - Identity filtering + fall-through

    func testFallsThroughWhenHigherPriorityHasNoIdentityBearingItems() throws {
        // Continue Watching present but all items lack a ratingKey → skip to curated.
        let candidates = [
            try candidate(.continueWatching, [nil, nil]),
            try candidate(.curated, ["c1"]),
        ]
        XCTAssertEqual(HeroSelectionPolicy.select(from: candidates, cap: 9).compactMap { $0.ratingKey }, ["c1"])
    }

    func testIdentitylessItemsAreDropped() throws {
        let candidates = [try candidate(.continueWatching, [nil, "cw2", nil, "cw4"])]
        XCTAssertEqual(HeroSelectionPolicy.select(from: candidates, cap: 9).compactMap { $0.ratingKey }, ["cw2", "cw4"])
    }

    // MARK: - Cap + empty

    func testCapLimitsResult() throws {
        let candidates = [try candidate(.continueWatching, ["a", "b", "c", "d"])]
        XCTAssertEqual(HeroSelectionPolicy.select(from: candidates, cap: 2).compactMap { $0.ratingKey }, ["a", "b"])
    }

    func testEmptyWhenNoCandidates() {
        XCTAssertTrue(HeroSelectionPolicy.select(from: [], cap: 9).isEmpty)
    }

    func testEmptyWhenNoUsableItems() throws {
        let candidates = [try candidate(.continueWatching, [nil]), try candidate(.recentlyAdded, [])]
        XCTAssertTrue(HeroSelectionPolicy.select(from: candidates, cap: 9).isEmpty)
    }

    func testEmptyWhenCapZero() throws {
        let candidates = [try candidate(.continueWatching, ["a"])]
        XCTAssertTrue(HeroSelectionPolicy.select(from: candidates, cap: 0).isEmpty)
    }

    func testPriorityConstantOrder() {
        XCTAssertEqual(HeroSelectionPolicy.priority, [.continueWatching, .curated, .recentlyAdded, .other])
    }
}
