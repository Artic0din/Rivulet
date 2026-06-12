//
//  AdaptiveTint.swift
//  Rivulet
//
//  ADO-06 — adaptive, artwork-driven background tint.
//
//  An Apple-TV-style atmospheric touch: the hero / detail backdrop is washed with
//  a subtle tint derived from the dominant colour of the artwork that is ALREADY
//  on screen. No new image fetch and no new data source — extraction piggybacks
//  the existing `ImageCacheManager` (cache hit for art the screen is displaying),
//  runs off the main actor, and is memoised per item so each backdrop is sampled
//  at most once.
//
//  The decision logic is split into pure, `nonisolated`, unit-testable pieces
//  (`ArtworkColorExtractor`, `ArtworkTintPolicy`); the SwiftUI layer
//  (`AdaptiveTintLayer`) only wires those to the environment and the cache.
//
//  Readability first: under Increase Contrast the tint is dropped entirely (the
//  screen falls back to its current dark backdrop); under Reduce Transparency the
//  intensity is reduced; under Reduce Motion the tint appears without an animated
//  fade. The tint is always subtle and sits beneath the existing legibility
//  scrims, so it can never lower text contrast below the current baseline.
//

import SwiftUI
import CoreImage

// MARK: - Colour value type

/// A plain RGB triple in 0...1, decoupled from SwiftUI/UIKit so the policy and
/// extractor stay pure and `Sendable`.
nonisolated struct RGBColor: Equatable, Sendable {
    let red: Double
    let green: Double
    let blue: Double

    var color: Color { Color(red: red, green: green, blue: blue) }
}

// MARK: - Tint policy (pure)

nonisolated enum ArtworkTintPolicy {
    /// The resolved tint to render: a muted colour plus the opacity to apply at
    /// the top of the backdrop.
    struct Resolved: Equatable, Sendable {
        let color: RGBColor
        let opacity: Double
    }

    /// Baseline tint opacity (top of the backdrop; it falls off to clear).
    static let baseOpacity: Double = 0.42
    /// Lowered intensity when the user prefers reduced transparency.
    static let reducedTransparencyOpacity: Double = 0.22
    /// Channel ceiling so a bright poster can't wash out the backdrop or text.
    static let maxChannel: Double = 0.6

    /// Resolves the tint to render, honouring accessibility. Returns nil to mean
    /// "no tint — keep the current backdrop":
    ///   - nil base colour (nothing extracted yet / extraction failed),
    ///   - Increase Contrast on (readability takes precedence over atmosphere).
    /// Reduce Transparency lowers the opacity rather than removing the tint.
    static func resolvedTint(
        base: RGBColor?,
        reduceTransparency: Bool,
        increaseContrast: Bool
    ) -> Resolved? {
        guard let base else { return nil }
        if increaseContrast { return nil }
        let opacity = reduceTransparency ? reducedTransparencyOpacity : baseOpacity
        return Resolved(color: muted(base), opacity: opacity)
    }

    /// Darkens an overly-bright colour so the tint reads as ambient atmosphere,
    /// not a colour cast over the UI. Hue is preserved (uniform channel scale);
    /// dark/moderate colours pass through unchanged.
    static func muted(_ c: RGBColor) -> RGBColor {
        let peak = max(c.red, c.green, c.blue)
        guard peak > maxChannel, peak > 0 else { return c }
        let scale = maxChannel / peak
        return RGBColor(red: c.red * scale, green: c.green * scale, blue: c.blue * scale)
    }
}

// MARK: - Colour extraction (pure, CPU; call off the main actor)

nonisolated enum ArtworkColorExtractor {
    /// Shared context; `workingColorSpace = nil` keeps the average in device RGB
    /// so the sampled value matches the source pixels (no colour-managed skew).
    private static let context = CIContext(options: [.workingColorSpace: NSNull()])

    /// Average colour of the image via a single `CIAreaAverage` pass — cheap, and
    /// a good "dominant ambient" for a subtle backdrop tint. nil if the image is
    /// empty or the render fails.
    static func averageColor(from cgImage: CGImage) -> RGBColor? {
        let input = CIImage(cgImage: cgImage)
        let extent = input.extent
        guard extent.width >= 1, extent.height >= 1 else { return nil }

        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: input,
            kCIInputExtentKey: CIVector(cgRect: extent)
        ]), let output = filter.outputImage else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(
            output,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        return RGBColor(
            red: Double(bitmap[0]) / 255.0,
            green: Double(bitmap[1]) / 255.0,
            blue: Double(bitmap[2]) / 255.0
        )
    }
}

// MARK: - Per-item cache (off-main, no new fetch)

/// Memoises the extracted base colour per item key so each backdrop is sampled at
/// most once. Extraction reuses the image the screen already loaded through
/// `ImageCacheManager` (cache hit), so no new network request is issued.
actor ArtworkTintCache {
    static let shared = ArtworkTintCache()

    private var cache: [String: RGBColor] = [:]
    /// Keys currently being extracted, to coalesce concurrent requests.
    private var inFlight: [String: Task<RGBColor?, Never>] = [:]

    /// Resolved base colour for `key`, or nil when there is no key/URL or the
    /// artwork could not be sampled. Cached after the first successful sample.
    func color(forKey key: String?, url: URL?) async -> RGBColor? {
        guard let key, let url else { return nil }
        if let cached = cache[key] { return cached }
        if let running = inFlight[key] { return await running.value }

        let task = Task<RGBColor?, Never> {
            guard let image = await ImageCacheManager.shared.image(for: url),
                  let cgImage = image.cgImage else { return nil }
            return ArtworkColorExtractor.averageColor(from: cgImage)
        }
        inFlight[key] = task
        let result = await task.value
        inFlight[key] = nil
        if let result { cache[key] = result }
        return result
    }
}

// MARK: - SwiftUI layer

/// A subtle, full-bleed tint derived from `artworkURL`, intended to sit directly
/// above the backdrop image and beneath the existing legibility scrims. Renders
/// nothing until a colour is resolved, and nothing at all under Increase Contrast.
struct AdaptiveTintLayer: View {
    let itemKey: String?
    let artworkURL: URL?

    @State private var base: RGBColor?
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let resolved = ArtworkTintPolicy.resolvedTint(
            base: base,
            reduceTransparency: reduceTransparency,
            increaseContrast: contrast == .increased
        )
        Group {
            if let resolved {
                LinearGradient(
                    stops: [
                        .init(color: resolved.color.color.opacity(resolved.opacity), location: 0.0),
                        .init(color: resolved.color.color.opacity(resolved.opacity * 0.4), location: 0.5),
                        .init(color: .clear, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .transition(.opacity)
            } else {
                Color.clear
            }
        }
        .allowsHitTesting(false)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.35), value: base)
        .task(id: itemKey) {
            base = await ArtworkTintCache.shared.color(forKey: itemKey, url: artworkURL)
        }
    }
}
