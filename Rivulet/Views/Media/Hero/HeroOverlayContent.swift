//
//  HeroOverlayContent.swift
//  Rivulet
//
//  The focusable foreground of the hero — logo/metadata/tagline + button row
//  + paging dots — with a transparent background so the layer behind shows
//  through. Used by the home screen inside a ScrollView so it sits at the
//  same level as the Continue Watching row (and scrolls together with it).
//

import SwiftUI
import os.log

private let overlayLog = Logger(subsystem: "com.rivulet.app", category: "HeroOverlay")

struct HeroOverlayContent: View {
    let items: [PlexMetadata]
    let serverURL: String
    let authToken: String
    @Binding var currentIndex: Int
    let onInfo: (PlexMetadata) -> Void
    let onPlay: (PlexMetadata) -> Void
    var onHeroFocused: (() -> Void)? = nil
    var onHeroExited: (() -> Void)? = nil
    /// Host gate: false while a detail/preview/player/resume surface is presented
    /// so the hero does not rotate behind it. Combined with scene phase + focus.
    var autoRotationEnabled: Bool = true

    @ObservedObject private var watchlistService = PlexWatchlistService.shared

    @State private var resolvedPlayTargets: [String: PlexMetadata] = [:]
    /// Cache of full-metadata resolutions keyed by ratingKey. Populated lazily
    /// by Watchlist toggles when the hub item lacked a Guid array; lets the
    /// bookmark icon reflect reality after a successful add.
    @State private var resolvedForWatchlistCache: [String: PlexMetadata] = [:]
    @State private var isResolvingPlay: Bool = false
    /// Lags behind `currentIndex` by `slideSwapDelay` so the backdrop has
    /// time to crossfade before the logo/metadata/buttons swap in.
    @State private var displayedIndex: Int = 0
    @FocusState private var focusedButton: HeroButton?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    /// How long to wait after `currentIndex` changes before swapping the
    /// visible slide content. Keeps the metadata from popping in ahead of
    /// the backdrop art (matches the detail view's brief hold).
    private static let slideSwapDelay: Duration = .milliseconds(100)

    private var currentItem: PlexMetadata? {
        guard !items.isEmpty else { return nil }
        let clamped = max(0, min(currentIndex, items.count - 1))
        return items[clamped]
    }

    private var displayedItem: PlexMetadata? {
        guard !items.isEmpty else { return nil }
        let clamped = max(0, min(displayedIndex, items.count - 1))
        return items[clamped]
    }

    private var canAdvance: Bool { items.count > 1 }

    /// Whether auto-rotation may run right now (pure policy + live state).
    private var rotationActive: Bool {
        HeroRotationPolicy.shouldRotate(
            itemCount: items.count,
            isHeroFocused: focusedButton != nil,
            isBusy: isResolvingPlay,
            isActive: autoRotationEnabled && scenePhase == .active
        )
    }

    /// Restart token for the rotation wait. Any change cancels and restarts the
    /// `.task`, which RESETS the interval — so a manual advance (currentIndex),
    /// focus enter/exit (pause/resume), busy state, scene phase, or item-set
    /// change all restart the countdown rather than firing mid-wait.
    private var rotationToken: String {
        "\(currentIndex)|\(focusedButton != nil)|\(isResolvingPlay)|\(items.count)|\(autoRotationEnabled)|\(scenePhase == .active)"
    }

    /// Must match the hero-section height computed in `PlexHomeView.contentView`
    /// and `PlexLibraryView.contentView` (`UIScreen.main.bounds.height - 180`).
    /// Set here explicitly so the layout doesn't depend on SwiftUI propagating
    /// the parent's `.frame(height:)` through the ZStack — which wasn't
    /// reaching the VStack reliably and caused the controls to overflow below
    /// the clipped hero bounds.
    private static let heroHeight: CGFloat = UIScreen.main.bounds.height - 200

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // Push everything to the bottom of the hero.
                Spacer(minLength: 0)

                if let item = displayedItem {
                    VStack(alignment: .leading, spacing: 28) {
                        HeroSlideContent(
                            item: item,
                            serverURL: serverURL,
                            authToken: authToken
                        )
                        .id(item.ratingKey ?? "idx-\(displayedIndex)")
                        .transition(.opacity)

                        HeroButtonRow(
                            isResolvingPlay: isResolvingPlay,
                            isOnWatchlist: resolvedTmdbId(for: item).map { watchlistService.contains(tmdbId: $0) } ?? false,
                            canAdvance: canAdvance,
                            focusedButton: $focusedButton,
                            onPlay: { handlePlay(item) },
                            onToggleWatchlist: { Task { await toggleWatchlist(for: item) } },
                            onInfo: { onInfo(item) },
                            onNext: { advance() }
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 120)
                }

                // Reserve bottom space for dots so logo/buttons sit above them.
                Spacer().frame(height: 120)
            }

            // Paging dots — pinned to the bottom of the hero independently
            // of the logo/buttons column.
            if canAdvance {
                pagingDots
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.black.opacity(0.35))
                    )
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.heroHeight)
        // Deterministic initial focus (E2-PR3/E2-PR4): when the hero focus
        // section is entered, Play is the preferred target rather than whatever
        // the focus engine would pick. Play is always present, so focus is never
        // stranded.
        .defaultFocus($focusedButton, .play)
        .onAppear {
            // Sync the displayed slide with the active index on first load.
            if displayedIndex != currentIndex {
                displayedIndex = currentIndex
            }
        }
        .onChange(of: currentIndex) { _, newIndex in
            Task { @MainActor in
                try? await Task.sleep(for: Self.slideSwapDelay)
                // Reduced Motion: swap content instantly with no crossfade.
                if reduceMotion {
                    displayedIndex = newIndex
                } else {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        displayedIndex = newIndex
                    }
                }
            }
        }
        .onChange(of: focusedButton) { oldButton, newButton in
            if newButton != nil && oldButton == nil {
                onHeroFocused?()
            } else if newButton == nil && oldButton != nil {
                onHeroExited?()
            }
        }
        .onChange(of: items.map(\.ratingKey)) { _, _ in
            if currentIndex >= items.count { currentIndex = 0 }
            if displayedIndex >= items.count { displayedIndex = 0 }
        }
        // Auto-rotation: wait one interval, then advance. The task is keyed on
        // `rotationToken`, so any state change (manual advance, focus enter/exit,
        // busy, scene phase, item set) cancels and restarts the wait — giving
        // automatic pause/resume and a clean timer reset on manual navigation,
        // with no per-rotation network or token exposure. Reduce Motion still
        // rotates; the swap is made instant by the `onChange(of: currentIndex)`
        // handler above.
        .task(id: rotationToken) {
            guard rotationActive else { return }
            try? await Task.sleep(for: .seconds(HeroRotationPolicy.intervalSeconds))
            guard !Task.isCancelled, rotationActive else { return }
            advance()
        }
    }

    // MARK: - Paging Dots

    private var pagingDots: some View {
        HStack(spacing: 10) {
            ForEach(0..<items.count, id: \.self) { idx in
                Capsule()
                    .fill(Color.white.opacity(idx == displayedIndex ? 1.0 : 0.35))
                    .frame(width: idx == displayedIndex ? 22 : 8, height: 8)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: displayedIndex)
            }
        }
    }

    // MARK: - Paging

    private func advance() {
        guard canAdvance else { return }
        // The backdrop reacts to `currentIndex` immediately; the visible
        // overlay follows ~100ms later via the onChange handler in `body`.
        // Index math is the tested `HeroRotationPolicy` (shared with auto-rotate).
        currentIndex = HeroRotationPolicy.nextIndex(current: currentIndex, count: items.count)
    }

    // MARK: - Play

    private func handlePlay(_ item: PlexMetadata) {
        guard !isResolvingPlay else { return }

        if let key = item.ratingKey, let cached = resolvedPlayTargets[key] {
            overlayLog.info("[HeroOverlay] Play (cached resolution) for \(key, privacy: .public)")
            onPlay(cached)
            return
        }

        // Fast path: movies and episodes need no resolution.
        if let type = item.type, type == "movie" || type == "episode" {
            onPlay(item)
            return
        }

        isResolvingPlay = true
        Task { @MainActor in
            let resolved = await HeroPlaySession.resolvePlaybackTarget(
                for: item,
                serverURL: serverURL,
                authToken: authToken
            )
            if let key = item.ratingKey {
                resolvedPlayTargets[key] = resolved
            }
            isResolvingPlay = false
            onPlay(resolved)
        }
    }

    // MARK: - Watchlist Toggle

    private func toggleWatchlist(for item: PlexMetadata) async {
        // Hub items often ship without the Guid array, so resolve full metadata
        // (which includes external IDs) before deriving a TMDB guid.
        let resolved = await resolvedForWatchlist(item)
        guard let tmdbId = resolved.tmdbId else {
            overlayLog.warning("Watchlist toggle aborted: no tmdbId on item \(resolved.ratingKey ?? "?", privacy: .public) title=\(resolved.title ?? "?", privacy: .public)")
            return
        }
        let guid = "tmdb://\(tmdbId)"
        let service = PlexWatchlistService.shared
        if service.contains(guid: guid) {
            overlayLog.info("Watchlist remove \(guid, privacy: .public)")
            await service.remove(guid: guid)
        } else {
            let watchType: PlexWatchlistItem.WatchlistType = (resolved.type == "show") ? .show : .movie
            let posterURL: URL? = {
                guard let thumbPath = resolved.thumb, !thumbPath.isEmpty else { return nil }
                return URL(string: "\(serverURL)\(thumbPath)?X-Plex-Token=\(authToken)")
            }()
            let watchlistItem = PlexWatchlistItem(
                id: guid,
                title: resolved.title ?? "",
                year: resolved.year,
                type: watchType,
                posterURL: posterURL,
                guids: [guid]
            )
            overlayLog.info("Watchlist add \(guid, privacy: .public)")
            await service.add(guid: guid, item: watchlistItem)
        }
    }

    private func resolvedForWatchlist(_ item: PlexMetadata) async -> PlexMetadata {
        if item.tmdbId != nil { return item }
        if let ratingKey = item.ratingKey, let cached = resolvedForWatchlistCache[ratingKey] {
            return cached
        }
        guard let ratingKey = item.ratingKey else { return item }
        do {
            let full = try await PlexNetworkManager.shared.getMetadata(
                serverURL: serverURL,
                authToken: authToken,
                ratingKey: ratingKey
            )
            resolvedForWatchlistCache[ratingKey] = full
            return full
        } catch {
            overlayLog.warning("Watchlist metadata resolve failed for \(ratingKey, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return item
        }
    }

    /// Returns the TMDB id for an item using the watchlist resolution cache when
    /// the raw hub item lacked a Guid array.
    private func resolvedTmdbId(for item: PlexMetadata) -> Int? {
        if let id = item.tmdbId { return id }
        if let key = item.ratingKey, let cached = resolvedForWatchlistCache[key] {
            return cached.tmdbId
        }
        return nil
    }

}
