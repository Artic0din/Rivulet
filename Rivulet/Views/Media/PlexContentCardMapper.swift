//
//  PlexContentCardMapper.swift
//  Rivulet
//
//  ADO-02 — maps a `PlexMetadata` row item to a `ContentCardModel` for
//  `LandscapeContentCard`, driving the canonical Content Presentation System
//  (`TitleTreatmentPolicy`, `ArtworkFallbackPolicy`, `MetadataHierarchyPolicy`,
//  `RuntimeFormatter`, `ContentRatingPresentation`) from existing Plex metadata.
//
//  Image URLs are built with the same token-safe pattern the existing cards use
//  (append `X-Plex-Token` only to a server-relative path, never to an
//  already-qualified URL, never to UI text). No provider calls, no new network,
//  no playback/Epic 1 boundary involvement — display mapping only.
//

import Foundation

nonisolated enum PlexContentCardMapper {

    /// Builds a `ContentCardModel` from a Plex row item.
    static func model(from item: PlexMetadata, serverURL: String, authToken: String) -> ContentCardModel {
        let title = item.title ?? "Unknown"

        // Logo: Plex clearLogo only here (TMDb/TVDb logos are a future ADO).
        let logoURL = url(for: item.clearLogoPath, serverURL: serverURL, authToken: authToken)
        let titleTreatment = TitleTreatmentPolicy.resolve(
            plexLogo: logoURL, tmdbLogo: nil, tvdbLogo: nil, title: title
        )

        // Artwork: Plex `art` is the landscape/backdrop; `thumb` (or the series
        // thumb for episodes) is the poster fallback.
        let landscapeURL = url(for: item.art, serverURL: serverURL, authToken: authToken)
        let posterPath = item.type == "episode"
            ? (item.grandparentThumb ?? item.parentThumb ?? item.thumb)
            : item.thumb
        let posterURL = url(for: posterPath, serverURL: serverURL, authToken: authToken)
        let artwork = ArtworkFallbackPolicy.resolve(
            landscape: landscapeURL, backdrop: nil, poster: posterURL
        )

        // Metadata hierarchy: Rating · Year · Runtime. No technical badges yet
        // (quality data is not mapped here — avoids badge spam; future ADO).
        let runtimeMinutes = item.duration.map { max(0, $0 / 60_000) }
        let hierarchy = MetadataHierarchyPolicy.build(
            title: titleTreatment,
            rating: item.contentRating,
            year: item.year,
            runtimeMinutes: runtimeMinutes,
            resolution: nil, video: nil, audio: nil,
            description: nil
        )

        return ContentCardModel(
            title: title,
            titleTreatment: titleTreatment,
            artwork: artwork,
            posterURL: posterURL,
            infoLine: hierarchy.infoLine,
            badges: hierarchy.badges
        )
    }

    /// True when the item has landscape artwork (Plex `art`), used to decide
    /// whether a landscape style can render without degrading to poster.
    static func hasLandscapeArtwork(_ item: PlexMetadata) -> Bool {
        let trimmed = item.art?.trimmingCharacters(in: .whitespaces)
        return trimmed?.isEmpty == false
    }

    /// Token-safe URL builder mirroring the existing cards: relative Plex paths
    /// get the server prefix + token (only if absent); already-qualified URLs
    /// pass through untouched.
    static func url(for path: String?, serverURL: String, authToken: String) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        if path.hasPrefix("http") { return URL(string: path) }
        var urlString = "\(serverURL)\(path)"
        if !urlString.contains("X-Plex-Token") {
            urlString += urlString.contains("?") ? "&" : "?"
            urlString += "X-Plex-Token=\(authToken)"
        }
        return URL(string: urlString)
    }
}
