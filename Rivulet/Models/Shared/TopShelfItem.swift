//
//  TopShelfItem.swift
//  Rivulet
//
//  Lightweight model for Top Shelf extension data sharing
//

import Foundation

/// Minimal data structure for Top Shelf items.
/// Shared between main app and TV Services Extension via App Groups.
///
/// SECURITY (E2-PR2 / NET-019 / E0-SEC-003): this payload is written into the
/// App Group container and read by the Top Shelf extension. It must remain
/// secret-free. It carries NO Plex token, token-bearing image URL, stream URL,
/// or credential. Artwork is handed off as `imageFileName` — an opaque local
/// filename inside the App Group `TopShelfImages` directory whose bytes the main
/// app fetched under its own authenticated/trust-aware session. The extension
/// only ever reads a local file; it never receives a token or performs an
/// authenticated network fetch.
///
/// This struct is intentionally duplicated in the `TopShelfExtension` target
/// (extensions cannot import the app module). Keep both copies in sync.
struct TopShelfItem: Codable, Sendable, Equatable {
    let ratingKey: String
    let title: String
    let subtitle: String?         // Show name for episodes
    /// Opaque local filename within the App Group `TopShelfImages` directory, or
    /// `nil` when no safe local image is available (extension falls back to no
    /// image). Never a remote/token-bearing URL. Optional so payloads written by
    /// older builds (which used a token-bearing `imageURL`) decode safely as
    /// "no image" instead of failing.
    let imageFileName: String?
    let progress: Double          // 0.0-1.0 watch progress
    let type: String              // "movie" or "episode"
    let lastWatched: Date
    let serverIdentifier: String  // Non-secret server identifier for deep link
}
