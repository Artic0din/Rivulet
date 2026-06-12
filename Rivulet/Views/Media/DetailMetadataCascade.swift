//
//  DetailMetadataCascade.swift
//  Rivulet
//
//  E3-PR4 — deterministic detail-page metadata cascade.
//
//  The detail hero builds its metadata lines (type label + genres, and the
//  year·duration chronology line) with inline conditionals scattered in the
//  3.7k-line `MediaDetailView`. That made the canonical ordering implicit and
//  untestable. This pure policy owns the ordering and nil-filtering so the
//  cascade is deterministic and unit-tested; the view renders from its output.
//
//  Behavior-preserving: the segment order and contents exactly reproduce the
//  prior inline logic. Pure and `nonisolated` so it is callable/testable from
//  any context. It owns *ordering of textual segments only* — badges, the
//  rating star, and the bordered content-rating chip remain view concerns.
//

import Foundation

nonisolated enum DetailMetadataCascade {

    /// Primary metadata parts shown before the content-rating chip:
    /// the media-type label (when applicable) followed by up to `maxGenres`
    /// genres, in order. Reproduces `MediaDetailView.heroMetadataParts`.
    static func primaryParts(kind: MediaKind, genres: [String], maxGenres: Int = 2) -> [String] {
        var parts: [String] = []

        switch kind {
        case .show, .episode, .season:
            parts.append("TV Show")
        case .movie:
            parts.append("Movie")
        case .collection, .person, .unknown:
            break
        }

        if maxGenres > 0 {
            for genre in genres.prefix(maxGenres) {
                parts.append(genre)
            }
        }

        return parts
    }

    /// Chronology parts for the quality row: year then duration, each included
    /// only when present, in that fixed order. The view joins these with a "·"
    /// separator — returning an ordered, nil-filtered array makes the
    /// separator logic deterministic (no `a != nil && b != nil` branching).
    static func chronologyParts(year: Int?, duration: String?) -> [String] {
        var parts: [String] = []
        if let year { parts.append(String(year)) }
        if let duration { parts.append(duration) }
        return parts
    }
}
