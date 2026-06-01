//
//  PlexContentCardMapperTests.swift
//  RivuletTests
//
//  ADO-02 — PlexMetadata → ContentCardModel mapping (token-safe, policy-driven).
//

import XCTest
@testable import Rivulet

final class PlexContentCardMapperTests: XCTestCase {

    private let server = "https://plex.example.com:32400"
    private let token = "secrettoken"

    private func item(
        type: String = "movie",
        title: String? = "Dune",
        art: String? = "/art/1",
        thumb: String? = "/thumb/1",
        rating: String? = "M",
        year: Int? = 2021,
        durationMs: Int? = 9_300_000
    ) throws -> PlexMetadata {
        // Build via JSON to mirror real decoding. No clearLogo set → text title.
        var fields = ["\"type\": \"\(type)\""]
        if let title { fields.append("\"title\": \"\(title)\"") }
        if let art { fields.append("\"art\": \"\(art)\"") }
        if let thumb { fields.append("\"thumb\": \"\(thumb)\"") }
        if let rating { fields.append("\"contentRating\": \"\(rating)\"") }
        if let year { fields.append("\"year\": \(year)") }
        if let durationMs { fields.append("\"duration\": \(durationMs)") }
        let json = "{ \"ratingKey\": \"1\", \(fields.joined(separator: ",")) }".data(using: .utf8)!
        return try JSONDecoder().decode(PlexMetadata.self, from: json)
    }

    // MARK: - URL building (token safety)

    func testRelativePathGetsServerPrefixAndToken() {
        let url = PlexContentCardMapper.url(for: "/library/art/1", serverURL: server, authToken: token)
        XCTAssertEqual(url?.absoluteString, "\(server)/library/art/1?X-Plex-Token=\(token)")
    }

    func testAlreadyQualifiedURLPassesThroughWithoutToken() {
        let url = PlexContentCardMapper.url(for: "https://cdn.example.com/x.png", serverURL: server, authToken: token)
        XCTAssertEqual(url?.absoluteString, "https://cdn.example.com/x.png")
        XCTAssertFalse(url!.absoluteString.contains(token))
    }

    func testNilOrEmptyPathYieldsNil() {
        XCTAssertNil(PlexContentCardMapper.url(for: nil, serverURL: server, authToken: token))
        XCTAssertNil(PlexContentCardMapper.url(for: "", serverURL: server, authToken: token))
    }

    func testTokenNotDuplicatedWhenPresent() {
        let url = PlexContentCardMapper.url(for: "/art?X-Plex-Token=abc", serverURL: server, authToken: token)
        XCTAssertEqual(url?.absoluteString, "\(server)/art?X-Plex-Token=abc")
    }

    // MARK: - Model mapping

    func testMovieMapsLandscapeArtworkAndInfoLine() throws {
        let model = PlexContentCardMapper.model(from: try item(), serverURL: server, authToken: token)
        XCTAssertEqual(model.title, "Dune")
        if case .landscape(let u) = model.artwork {
            XCTAssertTrue(u.absoluteString.hasPrefix("\(server)/art/1"))
        } else {
            XCTFail("Expected landscape artwork, got \(model.artwork)")
        }
        XCTAssertEqual(model.infoLine, ["M", "2021", "2h 35m"]) // 9_300_000ms = 155min
        XCTAssertTrue(model.badges.isEmpty)
        XCTAssertEqual(model.titleTreatment, .text("Dune")) // no logo → text
    }

    func testFallsBackToPosterWhenNoArt() throws {
        let model = PlexContentCardMapper.model(from: try item(art: nil), serverURL: server, authToken: token)
        if case .posterDerived(let u) = model.artwork {
            XCTAssertTrue(u.absoluteString.hasPrefix("\(server)/thumb/1"))
        } else {
            XCTFail("Expected poster-derived artwork, got \(model.artwork)")
        }
    }

    func testHasLandscapeArtwork() throws {
        XCTAssertTrue(PlexContentCardMapper.hasLandscapeArtwork(try item(art: "/art/1")))
        XCTAssertFalse(PlexContentCardMapper.hasLandscapeArtwork(try item(art: nil)))
    }

    func testNoTokenLeakInTitleOrInfo() throws {
        let model = PlexContentCardMapper.model(from: try item(), serverURL: server, authToken: token)
        XCTAssertFalse(model.title.contains(token))
        XCTAssertFalse(model.infoLine.joined().contains(token))
    }
}
