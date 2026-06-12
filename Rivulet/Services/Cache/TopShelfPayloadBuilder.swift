//
//  TopShelfPayloadBuilder.swift
//  Rivulet
//
//  E2-PR2 — pure, testable construction of the secret-free Top Shelf payload.
//
//  Separates the PERSISTED, secret-free fields (`TopShelfDraft` → `TopShelfItem`)
//  from the TRANSIENT authenticated thumb URL used only in-app to fetch image
//  bytes. The token-bearing URL lives on the draft's `authenticatedThumbURL`
//  field, is consumed by the in-app image fetch, and is NEVER written to the App
//  Group payload, logged, or handed to the extension.
//

import Foundation

/// Non-secret, persisted-bound Top Shelf fields plus the transient authenticated
/// thumb URL (token-bearing) used only for the in-app byte fetch.
struct TopShelfDraft: Equatable, Sendable {
    let ratingKey: String
    let title: String
    let subtitle: String?
    let progress: Double
    let type: String
    let lastWatched: Date
    let serverIdentifier: String
    /// TRANSIENT. Carries `X-Plex-Token`. In-app fetch only — must not be
    /// persisted into the payload, logged, or shared with the extension.
    let authenticatedThumbURL: URL?
}

enum TopShelfPayloadBuilder {
    /// Build a secret-free draft from Plex metadata. `nil` when the item lacks a
    /// rating key. `serverIdentifier` is the non-secret deep-link server value.
    static func draft(
        from metadata: PlexMetadata,
        serverIdentifier: String,
        serverURL: String,
        token: String
    ) -> TopShelfDraft? {
        guard let ratingKey = metadata.ratingKey else { return nil }

        let title: String
        if metadata.type == "episode" {
            title = metadata.fullEpisodeTitle ?? metadata.title ?? "Unknown"
        } else {
            title = metadata.title ?? "Unknown"
        }

        // For episodes prefer the show poster (grandparentThumb) for display.
        let thumbPath: String
        if metadata.type == "episode" {
            thumbPath = metadata.grandparentThumb ?? metadata.parentThumb ?? metadata.thumb ?? ""
        } else {
            thumbPath = metadata.thumb ?? ""
        }

        let lastWatched: Date
        if let timestamp = metadata.lastViewedAt {
            lastWatched = Date(timeIntervalSince1970: TimeInterval(timestamp))
        } else {
            lastWatched = Date()
        }

        return TopShelfDraft(
            ratingKey: ratingKey,
            title: title,
            subtitle: metadata.grandparentTitle,
            progress: metadata.watchProgress ?? 0,
            type: metadata.type ?? "movie",
            lastWatched: lastWatched,
            serverIdentifier: serverIdentifier,
            authenticatedThumbURL: authenticatedThumbURL(thumbPath: thumbPath, serverURL: serverURL, token: token)
        )
    }

    /// Build the transient authenticated thumb URL (token in query). INTERNAL USE
    /// ONLY — callers must not persist or log the result. Mirrors the prior
    /// in-app URL construction; the difference is this URL is never stored in the
    /// App Group payload.
    static func authenticatedThumbURL(thumbPath: String, serverURL: String, token: String) -> URL? {
        guard !thumbPath.isEmpty, !token.isEmpty else { return nil }
        var string = thumbPath
        if !string.hasPrefix("http") {
            string = "\(serverURL)\(thumbPath)"
        }
        if !string.contains("X-Plex-Token") {
            string += string.contains("?") ? "&" : "?"
            string += "X-Plex-Token=\(token)"
        }
        return URL(string: string)
    }
}

extension TopShelfItem {
    /// Assemble the persisted, secret-free item from a draft plus the resolved
    /// opaque image filename (nil when no safe local image was produced). The
    /// draft's transient authenticated URL is intentionally dropped here.
    init(draft: TopShelfDraft, imageFileName: String?) {
        self.init(
            ratingKey: draft.ratingKey,
            title: draft.title,
            subtitle: draft.subtitle,
            imageFileName: imageFileName,
            progress: draft.progress,
            type: draft.type,
            lastWatched: draft.lastWatched,
            serverIdentifier: draft.serverIdentifier
        )
    }
}
