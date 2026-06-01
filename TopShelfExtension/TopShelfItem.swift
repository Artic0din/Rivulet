//
//  TopShelfItem.swift
//  TopShelfExtension
//
//  Lightweight model for Top Shelf extension data sharing.
//
//  DUPLICATE of `Rivulet/Models/Shared/TopShelfItem.swift` (extensions cannot
//  import the app module). Keep both copies in sync.
//

import Foundation

/// Minimal, secret-free Top Shelf item shared via App Groups. See the app-target
/// copy for the full security contract (E2-PR2 / NET-019): no token, no
/// token-bearing image URL, no stream URL, no credential. Artwork is referenced
/// by `imageFileName` (opaque local file in the App Group `TopShelfImages` dir).
struct TopShelfItem: Codable, Sendable, Equatable {
    let ratingKey: String
    let title: String
    let subtitle: String?
    /// Opaque local filename in the App Group `TopShelfImages` directory, or nil
    /// when no safe local image exists. Never a remote/token-bearing URL.
    let imageFileName: String?
    let progress: Double
    let type: String
    let lastWatched: Date
    let serverIdentifier: String
}
