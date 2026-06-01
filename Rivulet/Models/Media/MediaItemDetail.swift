//
//  MediaItemDetail.swift
//  Rivulet
//
//  Superset returned from provider.fullDetail(for:). MediaDetailView gates
//  its below-fold on detail arrival. Embeds the list-level MediaItem so
//  detail consumers don't need both types passed in.
//

import Foundation

struct MediaItemDetail: Sendable {
    let item: MediaItem

    let tagline: String?
    let genres: [String]
    let studios: [String]
    let cast: [MediaPerson]
    let directors: [MediaPerson]
    let writers: [MediaPerson]
    let chapters: [MediaChapter]
    let mediaSources: [MediaSource]
    let trailerURL: URL?
    let contentRating: String?
    let rating: Double?              // normalized 0–10

    // Wave 1 additions for the detail view
    let nextEpisode: MediaItem?      // shows only — Plex `OnDeck`, Jellyfin `/Shows/NextUp`
    let collections: [String]        // collection names this item is tagged with

    /// External TMDb id for this title, when known (from Plex `guid`/`Guid` or a
    /// native TMDb ref). Drives the content-status label lookup (ADO-04); nil
    /// when no external id is exposed. Defaulted so existing constructions are
    /// non-breaking.
    var tmdbId: Int? = nil
}
