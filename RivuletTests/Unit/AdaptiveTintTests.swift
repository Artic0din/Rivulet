//
//  AdaptiveTintTests.swift
//  RivuletTests
//
//  ADO-06 — pure seams of the adaptive artwork tint: colour extraction, muting,
//  and accessibility-aware resolution. The SwiftUI layer and the actor cache are
//  validated on device; only the deterministic logic is unit-tested here.
//

import XCTest
import CoreGraphics
@testable import Rivulet

final class AdaptiveTintTests: XCTestCase {

    // MARK: - resolvedTint (accessibility)

    func testNilBaseProducesNoTint() {
        XCTAssertNil(ArtworkTintPolicy.resolvedTint(base: nil, reduceTransparency: false, increaseContrast: false))
    }

    func testIncreaseContrastDisablesTint() {
        let base = RGBColor(red: 0.3, green: 0.4, blue: 0.5)
        XCTAssertNil(ArtworkTintPolicy.resolvedTint(base: base, reduceTransparency: false, increaseContrast: true))
    }

    func testDefaultUsesBaseOpacity() {
        let base = RGBColor(red: 0.3, green: 0.4, blue: 0.5)
        let r = ArtworkTintPolicy.resolvedTint(base: base, reduceTransparency: false, increaseContrast: false)
        XCTAssertEqual(r?.opacity, ArtworkTintPolicy.baseOpacity)
    }

    func testReduceTransparencyLowersOpacity() {
        let base = RGBColor(red: 0.3, green: 0.4, blue: 0.5)
        let r = ArtworkTintPolicy.resolvedTint(base: base, reduceTransparency: true, increaseContrast: false)
        XCTAssertEqual(r?.opacity, ArtworkTintPolicy.reducedTransparencyOpacity)
        XCTAssertLessThan(ArtworkTintPolicy.reducedTransparencyOpacity, ArtworkTintPolicy.baseOpacity)
    }

    // MARK: - muted

    func testMutedDarkensBrightColour() {
        let bright = RGBColor(red: 0.95, green: 0.9, blue: 0.85)
        let muted = ArtworkTintPolicy.muted(bright)
        let peak = max(muted.red, muted.green, muted.blue)
        XCTAssertLessThanOrEqual(peak, ArtworkTintPolicy.maxChannel + 0.0001)
    }

    func testMutedPreservesHueRatio() {
        // Uniform channel scaling keeps the colour's hue (channel ratios) intact.
        let bright = RGBColor(red: 1.0, green: 0.5, blue: 0.25)
        let muted = ArtworkTintPolicy.muted(bright)
        XCTAssertEqual(muted.green / muted.red, 0.5, accuracy: 0.001)
        XCTAssertEqual(muted.blue / muted.red, 0.25, accuracy: 0.001)
    }

    func testMutedLeavesModerateColourUnchanged() {
        let moderate = RGBColor(red: 0.4, green: 0.3, blue: 0.2)
        XCTAssertEqual(ArtworkTintPolicy.muted(moderate), moderate)
    }

    // MARK: - averageColor (gamma-robust: assert the dominant channel)

    private func solidImage(_ r: UInt8, _ g: UInt8, _ b: UInt8, size: Int = 4) -> CGImage {
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(
            data: nil, width: size, height: size, bitsPerComponent: 8,
            bytesPerRow: size * 4, space: cs,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        ctx.setFillColor(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
        return ctx.makeImage()!
    }

    func testAverageColorOfRedImageIsRedDominant() throws {
        let c = ArtworkColorExtractor.averageColor(from: solidImage(255, 0, 0))
        let c2 = try XCTUnwrap(c)
        XCTAssertGreaterThan(c2.red, 0.8)
        XCTAssertLessThan(c2.green, 0.2)
        XCTAssertLessThan(c2.blue, 0.2)
    }

    func testAverageColorOfWhiteImageIsBright() {
        let c = ArtworkColorExtractor.averageColor(from: solidImage(255, 255, 255))
        let c2 = try! XCTUnwrap(c)
        XCTAssertGreaterThan(c2.red, 0.9)
        XCTAssertGreaterThan(c2.green, 0.9)
        XCTAssertGreaterThan(c2.blue, 0.9)
    }

    func testAverageColorOfBlueImageIsBlueDominant() {
        let c = ArtworkColorExtractor.averageColor(from: solidImage(0, 0, 255))
        let c2 = try! XCTUnwrap(c)
        XCTAssertGreaterThan(c2.blue, 0.8)
        XCTAssertLessThan(c2.red, 0.2)
        XCTAssertLessThan(c2.green, 0.2)
    }
}
