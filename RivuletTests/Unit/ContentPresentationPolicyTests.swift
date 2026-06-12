//
//  ContentPresentationPolicyTests.swift
//  RivuletTests
//
//  E3-PR6 — the Content Presentation System policy layer.
//

import XCTest
@testable import Rivulet

final class ContentPresentationPolicyTests: XCTestCase {

    private let url = URL(string: "https://metadata-static.plex.tv/x.png")!
    private let url2 = URL(string: "https://image.tmdb.org/t/p/original/y.png")!

    // MARK: - Presentation style

    func testStyleCasesAreLandscapeAndPoster() {
        // Poster→landscape-on-focus was dropped (product decision); only the
        // landscape shelf and poster styles remain.
        XCTAssertEqual(Set(ContentPresentationStyle.allCases), [.landscape, .poster])
    }

    func testDefaultStyleIsPoster() {
        XCTAssertEqual(ContentPresentationStyle.default, .poster)
    }

    func testAccessibilityLabelStableAcrossFocusStates() {
        // The combined label must not depend on focus/landscape state.
        let label = ContentCardAccessibility.label(title: "Dune", infoLine: ["M", "2021"], badges: [])
        XCTAssertEqual(label, ContentCardAccessibility.label(title: "Dune", infoLine: ["M", "2021"], badges: []))
        XCTAssertEqual(label, "Dune, M, 2021")
    }

    // MARK: - Title treatment

    func testTitleLogoSourceOrder() {
        XCTAssertEqual(TitleTreatmentPolicy.resolve(plexLogo: url, tmdbLogo: url2, tvdbLogo: nil, title: "T"), .logo(url))
        XCTAssertEqual(TitleTreatmentPolicy.resolve(plexLogo: nil, tmdbLogo: url2, tvdbLogo: url, title: "T"), .logo(url2))
        XCTAssertEqual(TitleTreatmentPolicy.resolve(plexLogo: nil, tmdbLogo: nil, tvdbLogo: url, title: "T"), .logo(url))
    }

    func testTitleFallsBackToText() {
        XCTAssertEqual(TitleTreatmentPolicy.resolve(plexLogo: nil, tmdbLogo: nil, tvdbLogo: nil, title: "Severance"), .text("Severance"))
    }

    // MARK: - Artwork fallback

    func testArtworkFallbackOrder() {
        XCTAssertEqual(ArtworkFallbackPolicy.resolve(landscape: url, backdrop: url2, poster: url2), .landscape(url))
        XCTAssertEqual(ArtworkFallbackPolicy.resolve(landscape: nil, backdrop: url2, poster: url), .backdropCrop(url2))
        XCTAssertEqual(ArtworkFallbackPolicy.resolve(landscape: nil, backdrop: nil, poster: url), .posterDerived(url))
        XCTAssertEqual(ArtworkFallbackPolicy.resolve(landscape: nil, backdrop: nil, poster: nil), .placeholder)
    }

    // MARK: - Runtime

    func testRuntimeFormatting() {
        XCTAssertEqual(RuntimeFormatter.format(minutes: 152), "2h 32m")
        XCTAssertEqual(RuntimeFormatter.format(minutes: 47), "47m")
        XCTAssertEqual(RuntimeFormatter.format(minutes: 120), "2h")
        XCTAssertEqual(RuntimeFormatter.format(minutes: 60), "1h")
        XCTAssertNil(RuntimeFormatter.format(minutes: 0))
        XCTAssertNil(RuntimeFormatter.format(minutes: nil))
        XCTAssertNil(RuntimeFormatter.format(minutes: -5))
    }

    // MARK: - Content rating

    func testRatingNormalization() {
        XCTAssertEqual(ContentRatingPresentation.normalized("  MA15+ "), "MA15+")
        XCTAssertEqual(ContentRatingPresentation.normalized("TV-MA"), "TV-MA")
        XCTAssertNil(ContentRatingPresentation.normalized("   "))
        XCTAssertNil(ContentRatingPresentation.normalized(nil))
    }

    // MARK: - Technical badges

    func testBadgeOrderResolutionVideoAudio() {
        XCTAssertEqual(
            TechnicalBadgePolicy.badges(resolution: "4K", video: "Dolby Vision", audio: "Atmos"),
            ["4K", "Dolby Vision", "Atmos"]
        )
    }

    func testBadgeNilDimensionsSkipped() {
        XCTAssertEqual(TechnicalBadgePolicy.badges(resolution: "4K", video: nil, audio: "5.1"), ["4K", "5.1"])
        XCTAssertEqual(TechnicalBadgePolicy.badges(resolution: nil, video: nil, audio: nil), [])
        XCTAssertEqual(TechnicalBadgePolicy.badges(resolution: " ", video: "HDR10", audio: nil), ["HDR10"])
    }

    func testHighestPriorityVideo() {
        XCTAssertEqual(TechnicalBadgePolicy.highestPriority(from: ["HDR10", "Dolby Vision"], order: TechnicalBadgePolicy.videoPriority), "Dolby Vision")
        XCTAssertEqual(TechnicalBadgePolicy.highestPriority(from: ["hdr10"], order: TechnicalBadgePolicy.videoPriority), "HDR10")
        XCTAssertNil(TechnicalBadgePolicy.highestPriority(from: ["SDR"], order: TechnicalBadgePolicy.videoPriority))
    }

    func testHighestPriorityAudio() {
        // Candidates contain "Atmos" (not the spelling "Dolby Atmos"), so the
        // first matching priority entry is "Atmos".
        XCTAssertEqual(TechnicalBadgePolicy.highestPriority(from: ["5.1", "TrueHD", "Atmos"], order: TechnicalBadgePolicy.audioPriority), "Atmos")
        // "Dolby Atmos" spelling present → it outranks everything.
        XCTAssertEqual(TechnicalBadgePolicy.highestPriority(from: ["5.1", "Dolby Atmos", "TrueHD"], order: TechnicalBadgePolicy.audioPriority), "Dolby Atmos")
        XCTAssertEqual(TechnicalBadgePolicy.highestPriority(from: ["5.1", "DTS-HD MA"], order: TechnicalBadgePolicy.audioPriority), "DTS-HD MA")
    }

    // MARK: - Metadata hierarchy

    func testMetadataHierarchyAssembly() {
        let h = MetadataHierarchyPolicy.build(
            title: .text("Dune"),
            rating: "M",
            year: 2021,
            runtimeMinutes: 155,
            resolution: "4K",
            video: "Dolby Vision",
            audio: "Atmos",
            description: "  A noble family becomes embroiled in a war.  "
        )
        XCTAssertEqual(h.title, .text("Dune"))
        XCTAssertEqual(h.infoLine, ["M", "2021", "2h 35m"])
        XCTAssertEqual(h.badges, ["4K", "Dolby Vision", "Atmos"])
        XCTAssertEqual(h.description, "A noble family becomes embroiled in a war.")
    }

    func testMetadataHierarchyNilFiltering() {
        let h = MetadataHierarchyPolicy.build(
            title: .text("Unknown"),
            rating: nil, year: nil, runtimeMinutes: nil,
            resolution: nil, video: nil, audio: nil,
            description: "   "
        )
        XCTAssertTrue(h.infoLine.isEmpty)
        XCTAssertTrue(h.badges.isEmpty)
        XCTAssertNil(h.description)
    }
}
