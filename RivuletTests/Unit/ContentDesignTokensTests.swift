//
//  ContentDesignTokensTests.swift
//  RivuletTests
//
//  E3-PR2 — pin the canonical content design tokens.
//
//  These tests lock the token seeds to the exact literal values they replaced
//  in GlassRowStyle, so the literal→token refactor stays behavior-identical and
//  any accidental future drift is caught. They also assert the metadata type
//  ramp is strictly descending and aliases ScaledDimensions.
//

import XCTest
import CoreGraphics
@testable import Rivulet

final class ContentDesignTokensTests: XCTestCase {

    func testOpacitySeeds() {
        XCTAssertEqual(ContentDesignTokens.Opacity.glassFillFocused, 0.18)
        XCTAssertEqual(ContentDesignTokens.Opacity.glassFillResting, 0.08)
        XCTAssertEqual(ContentDesignTokens.Opacity.glassBorderFocused, 0.30)
        XCTAssertEqual(ContentDesignTokens.Opacity.glassBorderResting, 0.10)
        XCTAssertEqual(ContentDesignTokens.Opacity.glassShadowFocused, 0.10)
        XCTAssertEqual(ContentDesignTokens.Opacity.buttonFillResting, 0.15)
        XCTAssertEqual(ContentDesignTokens.Opacity.actionFillPrimaryResting, 0.20)
        XCTAssertEqual(ContentDesignTokens.Opacity.actionFillSecondaryResting, 0.12)
        XCTAssertEqual(ContentDesignTokens.Opacity.actionStrokeResting, 0.20)
    }

    func testScaleSeeds() {
        XCTAssertEqual(ContentDesignTokens.Scale.rowFocused, 1.02)
        XCTAssertEqual(ContentDesignTokens.Scale.actionFocused, 1.08)
        XCTAssertEqual(ContentDesignTokens.Scale.buttonFocused, 1.10)
        XCTAssertEqual(ContentDesignTokens.Scale.pressed, 0.95)
        XCTAssertEqual(ContentDesignTokens.Scale.resting, 1.0)
    }

    func testShapeSeeds() {
        XCTAssertEqual(ContentDesignTokens.Shape.cornerRadius, 16)
        XCTAssertEqual(ContentDesignTokens.Shape.shadowRadius, 8)
        XCTAssertEqual(ContentDesignTokens.Shape.shadowY, 2)
    }

    func testTypeRampIsDescendingAndAliasesScaledDimensions() {
        XCTAssertEqual(ContentDesignTokens.TypeRamp.hero, ScaledDimensions.heroTitleSize)
        XCTAssertEqual(ContentDesignTokens.TypeRamp.section, ScaledDimensions.sectionTitleSize)
        XCTAssertEqual(ContentDesignTokens.TypeRamp.cardTitle, ScaledDimensions.posterTitleSize)
        XCTAssertEqual(ContentDesignTokens.TypeRamp.cardSubtitle, ScaledDimensions.posterSubtitleSize)

        let ramp = [
            ContentDesignTokens.TypeRamp.hero,
            ContentDesignTokens.TypeRamp.section,
            ContentDesignTokens.TypeRamp.cardTitle,
            ContentDesignTokens.TypeRamp.cardSubtitle
        ]
        XCTAssertEqual(ramp, ramp.sorted(by: >), "Type ramp must be strictly large → small")
        XCTAssertEqual(Set(ramp).count, ramp.count, "Type ramp steps must be distinct")
    }

    func testRestingScaleIsIdentity() {
        // Resting must be exactly 1.0 so token adoption never shifts unfocused layout.
        XCTAssertEqual(ContentDesignTokens.Scale.resting, 1.0, accuracy: 0.0)
    }
}
