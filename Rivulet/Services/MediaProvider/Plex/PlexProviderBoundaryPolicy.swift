//
//  PlexProviderBoundaryPolicy.swift
//  Rivulet
//
//  Epic 1 ownership policy for Plex's MediaProvider adapter boundary.
//

import Foundation

enum PlexProviderBoundaryPolicy {
    static let adapterOwner = "PlexProvider / MediaProvider adapter"

    static let corePMSBoundary = "Core PMS browse, detail, home, search, metadata, and state-write calls are selected server token scoped and owned by PlexProvider plus PlexNetworkManager."

    static let watchStateBoundary = "Watch state and timeline writes route through PlexWatchStateRequestFactory so PMS state-write URL construction, token transport, and method ownership stay centralized."

    static let watchlistReadBoundary = "Watchlist read status delegates to PlexWatchlistService, which owns the account-token Discover/provider cache boundary."

    static let watchlistWriteBoundary = "Watchlist writes require the Plex account token plus display metadata for optimistic cache entries; ref-only MediaProvider calls do not safely carry both inputs."

    static let refOnlyWatchlistWriteUnsupportedMessage = "Watchlist writes require PlexWatchlistService with account token scope and MediaItem display metadata; ref-only MediaProvider watchlist writes are intentionally disabled."
}
