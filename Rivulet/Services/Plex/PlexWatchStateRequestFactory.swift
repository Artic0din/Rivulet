//
//  PlexWatchStateRequestFactory.swift
//  Rivulet
//
//  Owns PMS watch-state and timeline request construction.
//

import Foundation

/// Central request builder for PMS state-write endpoints.
///
/// Epic 1 owns the PMS state-write boundary and request hygiene. Epic 4 owns
/// playback behavior, so legacy playback reporter HTTP methods are preserved
/// here rather than silently normalized during the platform modernization work.
enum PlexWatchStateRequestFactory {
    static let adapterOwner = "PMS state-write adapter"
    static let playbackReporterLegacyMethodRationale = "Playback reporter GET behavior is retained until Epic 4 validates playback-side timeline semantics."

    enum HeaderPolicy {
        case standardPlex
        case tokenOnly
    }

    enum ScrobbleAction {
        case watched
        case unwatched

        var path: String {
            switch self {
            case .watched:
                return "/:/scrobble"
            case .unwatched:
                return "/:/unscrobble"
            }
        }
    }

    static func timelineRequest(
        serverURL: String,
        authToken: String,
        ratingKey: String,
        timeMs: Int,
        state: String,
        durationMs: Int? = nil,
        method: String,
        headerPolicy: HeaderPolicy,
        includeClientQueryItems: Bool
    ) throws -> URLRequest {
        var queryItems = [
            URLQueryItem(name: "key", value: "/library/metadata/\(ratingKey)"),
            URLQueryItem(name: "ratingKey", value: ratingKey),
            URLQueryItem(name: "time", value: "\(timeMs)"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "identifier", value: "com.plexapp.plugins.library")
        ]

        if let durationMs {
            queryItems.append(URLQueryItem(name: "duration", value: "\(durationMs)"))
        }

        if includeClientQueryItems {
            queryItems.append(contentsOf: plexClientQueryItems)
        }

        return try makeRequest(
            serverURL: serverURL,
            path: "/:/timeline",
            authToken: authToken,
            method: method,
            queryItems: queryItems,
            headerPolicy: headerPolicy
        )
    }

    static func scrobbleRequest(
        serverURL: String,
        authToken: String,
        ratingKey: String,
        action: ScrobbleAction,
        method: String,
        headerPolicy: HeaderPolicy
    ) throws -> URLRequest {
        try makeRequest(
            serverURL: serverURL,
            path: action.path,
            authToken: authToken,
            method: method,
            queryItems: [
                URLQueryItem(name: "key", value: ratingKey),
                URLQueryItem(name: "identifier", value: "com.plexapp.plugins.library")
            ],
            headerPolicy: headerPolicy
        )
    }

    private static func makeRequest(
        serverURL: String,
        path: String,
        authToken: String,
        method: String,
        queryItems: [URLQueryItem],
        headerPolicy: HeaderPolicy
    ) throws -> URLRequest {
        let base = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard var components = URLComponents(string: "\(base)\(path)") else {
            throw PlexAPIError.invalidURL
        }

        components.queryItems = queryItems.filter { !isForbiddenTokenQueryName($0.name) }

        guard let url = components.url else {
            throw PlexAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        applyHeaders(to: &request, authToken: authToken, policy: headerPolicy)
        return request
    }

    private static var plexClientQueryItems: [URLQueryItem] {
        [
            URLQueryItem(name: "X-Plex-Client-Identifier", value: PlexAPI.clientIdentifier),
            URLQueryItem(name: "X-Plex-Platform", value: PlexAPI.platform),
            URLQueryItem(name: "X-Plex-Device", value: PlexAPI.deviceName),
            URLQueryItem(name: "X-Plex-Product", value: PlexAPI.productName)
        ]
    }

    private static func applyHeaders(
        to request: inout URLRequest,
        authToken: String,
        policy: HeaderPolicy
    ) {
        request.addValue(authToken, forHTTPHeaderField: "X-Plex-Token")

        guard policy == .standardPlex else {
            return
        }

        request.addValue(PlexAPI.clientIdentifier, forHTTPHeaderField: "X-Plex-Client-Identifier")
        request.addValue(PlexAPI.productName, forHTTPHeaderField: "X-Plex-Product")
        request.addValue(PlexAPI.platform, forHTTPHeaderField: "X-Plex-Platform")
        request.addValue(PlexAPI.deviceName, forHTTPHeaderField: "X-Plex-Device")
    }

    private static func isForbiddenTokenQueryName(_ name: String) -> Bool {
        ["x-plex-token", "token", "authtoken", "accesstoken"].contains(name.lowercased())
    }
}
