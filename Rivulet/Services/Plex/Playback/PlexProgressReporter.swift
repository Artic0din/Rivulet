//
//  PlexProgressReporter.swift
//  Rivulet
//
//  Reports playback progress to Plex server for timeline tracking
//

import Foundation

/// Reports playback progress and watch status to Plex server
actor PlexProgressReporter {
    static let shared = PlexProgressReporter()

    private var lastReportedTimes: [String: TimeInterval] = [:]

    private init() {}

    // MARK: - Progress Reporting

    /// Reports current playback position to Plex
    /// - Parameters:
    ///   - ratingKey: The Plex rating key for the media item
    ///   - time: Current playback time in seconds
    ///   - duration: Total duration in seconds
    ///   - state: Playback state ("playing", "paused", "stopped")
    ///   - forceReport: If true, bypasses throttle to report immediately (for state changes)
    func reportProgress(
        ratingKey: String,
        time: TimeInterval,
        duration: TimeInterval,
        state: String,
        forceReport: Bool = false
    ) async {
        guard !ratingKey.isEmpty else { return }

        // Throttle reports - only report if time changed significantly (unless forced)
        if !forceReport, let lastTime = lastReportedTimes[ratingKey], abs(time - lastTime) < 5 {
            return
        }
        lastReportedTimes[ratingKey] = time

        guard let server = await getServer() else { return }

        let timeMs = Int(time * 1000)
        let durationMs = Int(duration * 1000)

        do {
            let request = try await MainActor.run {
                try PlexWatchStateRequestFactory.timelineRequest(
                    serverURL: server.address,
                    authToken: server.token,
                    ratingKey: ratingKey,
                    timeMs: timeMs,
                    state: state,
                    durationMs: durationMs,
                    method: "GET",
                    headerPolicy: .tokenOnly,
                    includeClientQueryItems: true
                )
            }
            _ = try await PlexNetworkManager.shared.requestData(request)
        } catch {
            playerDebugLog("📊 PlexProgress: Failed to report progress: \(error)")
        }
    }

    /// Marks an item as fully watched (scrobble)
    /// - Parameter ratingKey: The Plex rating key for the media item
    func markAsWatched(ratingKey: String) async {
        guard !ratingKey.isEmpty else { return }
        guard let server = await getServer() else { return }

        do {
            let request = try await MainActor.run {
                try PlexWatchStateRequestFactory.scrobbleRequest(
                    serverURL: server.address,
                    authToken: server.token,
                    ratingKey: ratingKey,
                    action: .watched,
                    method: "GET",
                    headerPolicy: .tokenOnly
                )
            }
            _ = try await PlexNetworkManager.shared.requestData(request)
        } catch {
            playerDebugLog("📊 PlexProgress: Failed to mark as watched: \(error)")
        }
    }

    /// Marks an item as unwatched
    /// - Parameter ratingKey: The Plex rating key for the media item
    func markAsUnwatched(ratingKey: String) async {
        guard !ratingKey.isEmpty else { return }
        guard let server = await getServer() else { return }

        do {
            let request = try await MainActor.run {
                try PlexWatchStateRequestFactory.scrobbleRequest(
                    serverURL: server.address,
                    authToken: server.token,
                    ratingKey: ratingKey,
                    action: .unwatched,
                    method: "GET",
                    headerPolicy: .tokenOnly
                )
            }
            _ = try await PlexNetworkManager.shared.requestData(request)
        } catch {
            playerDebugLog("📊 PlexProgress: Failed to mark as unwatched: \(error)")
        }
    }

    // MARK: - Helpers

    private func getServer() async -> (address: String, token: String)? {
        await MainActor.run {
            let authManager = PlexAuthManager.shared
            guard let address = authManager.selectedServerURL,
                  let token = authManager.selectedServerToken else {
                return nil
            }
            return (address, token)
        }
    }
}
