//
//  ContentView.swift
//  Rivulet
//
//  Created by Bain Gurley on 11/28/25.
//

import SwiftUI
import SwiftData
import Combine
import os.log
import UIKit

private let splashLog = Logger(subsystem: "com.rivulet.app", category: "Splash")

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var dataStore = PlexDataStore.shared
    @StateObject private var authManager = PlexAuthManager.shared
    #if DEBUG
    @State private var showSplash = false
    #else
    @State private var showSplash = true
    #endif

    /// How the SwiftData store was built at launch. Drives the non-fatal
    /// "local history was reset" notice (audit finding C-1). Defaults to
    /// `.persistent` so previews/tests need not supply it.
    private let storeResolution: ModelStoreResolution
    @State private var showStoreNotice: Bool

    init(storeResolution: ModelStoreResolution = .persistent) {
        self.storeResolution = storeResolution
        _showStoreNotice = State(initialValue: storeResolution != .persistent)
    }

    var body: some View {
        TVSidebarView()
            .modifier(AutoPlayLauncherModifier())
            .overlay {
                if showSplash {
                    splashOverlay
                        .transition(.opacity)
                }
            }
            .overlay(alignment: .top) {
                if showStoreNotice {
                    storeNoticeBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.easeOut(duration: 0.4), value: showSplash)
            .animation(.easeOut(duration: 0.3), value: showStoreNotice)
        .onChange(of: authManager.hasCredentials) { _, hasCredentials in
            splashLog.info("hasCredentials changed to \(hasCredentials)")
            if !hasCredentials {
                splashLog.info("No credentials — dismissing splash")
                showSplash = false
            }
        }
        .onChange(of: dataStore.isHomeContentReady) { _, isReady in
            splashLog.info("isHomeContentReady changed to \(isReady), showSplash=\(self.showSplash)")
            if isReady {
                // PERF-001/002: first visually-useful home shell is reached when
                // home content is ready (drives splash dismissal). Closes the
                // launch interval opened at app-task start.
                HomePerformance.tracer.markFirstUsefulScreen()
                Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    splashLog.info("Debounce complete — isHomeContentReady=\(self.dataStore.isHomeContentReady), showSplash=\(self.showSplash)")
                    if dataStore.isHomeContentReady {
                        splashLog.info("Dismissing splash — home content ready")
                        showSplash = false
                    }
                }
            }
        }
        .task {
            // PERF-001/002 launch reference point (in-app). Absolute cold-launch
            // timing also uses OS process-launch signposts per Epic 0 perf doc.
            HomePerformance.tracer.beginLaunch()
            // Bootstrap the agnostic media layer registries. Touching the
            // metadata registry initializes it (and registers TMDB). The
            // provider registry needs the active Plex auth state — populate
            // now and again whenever the URL/token changes via the onChange
            // observers below.
            _ = MetadataSourceRegistry.shared
            MediaProviderRegistry.shared.populateFromCurrentAuth()
            MusicProviderRegistry.shared.populateFromCurrentAuth()
            MusicQueue.shared.configure(registry: MusicProviderRegistry.shared)

            splashLog.info("Splash task started — hasCredentials=\(self.authManager.hasCredentials)")
            if !authManager.hasCredentials {
                splashLog.info("No credentials on launch — dismissing splash immediately")
                showSplash = false
                return
            }
            // Safety timeout
            try? await Task.sleep(for: .seconds(15))
            if showSplash {
                splashLog.warning("Safety timeout reached (15s) — force dismissing splash")
                showSplash = false
            }
        }
        .onChange(of: authManager.selectedServerURL) { _, _ in
            MediaProviderRegistry.shared.populateFromCurrentAuth()
            MusicProviderRegistry.shared.populateFromCurrentAuth()
        }
        .onChange(of: authManager.selectedServerToken) { _, _ in
            MediaProviderRegistry.shared.populateFromCurrentAuth()
            MusicProviderRegistry.shared.populateFromCurrentAuth()
        }
        // Refresh the server-side library list on every transition
        // to .active so a library added or renamed on the Plex server
        // while Rivulet was backgrounded (or while the user was on the
        // tvOS Home Screen) surfaces without an app restart.
        // `loadLibrariesIfNeeded` returns early once the cache is
        // populated, so without this hook the cached list never
        // reconciles against current server state. Library visibility
        // is fail-open (a hidden-libraries deny-list), so a freshly
        // discovered library auto-appears in the sidebar.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await dataStore.refreshLibraries() }
            }
        }
    }

    /// Non-fatal notice shown when the persistent store had to be reset or fell
    /// back to memory at launch (audit finding C-1). Dismissable with the remote.
    private var storeNoticeBanner: some View {
        let message: String
        switch storeResolution {
        case .persistent:
            message = ""
        case .recoveredAfterReset:
            message = "Local watch history was reset after a storage problem. Your Plex account and watched state on the server are unaffected."
        case .inMemoryFallback:
            message = "Local storage is unavailable, so watch history won't be saved this session. Your Plex account is unaffected."
        }

        return Button {
            showStoreNotice = false
        } label: {
            HStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                Text(message)
                    .font(.callout)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 24)
                Text("Dismiss")
                    .font(.callout.weight(.semibold))
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 48)
        .padding(.top, 32)
    }

    private var splashOverlay: some View {
        ZStack {
            VStack(spacing: 24) {
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.white.opacity(0.6))

                ProgressView()
                    .tint(.white.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial, ignoresSafeAreaEdges: .all)
        .allowsHitTesting(true)
    }
}

// MARK: - AutoPlay Launcher (Debug Testing)

/// Reads RIVULET_AUTOPLAY env vars (passed via `xcrun devicectl`) and auto-launches playback.
/// Used for automated playback testing from the CLI.
private struct AutoPlayLauncherModifier: ViewModifier {
    @State private var hasLaunched = false

    func body(content: Content) -> some View {
        content
            .task {
                guard !hasLaunched else { return }
                let env = ProcessInfo.processInfo.environment
                guard env["RIVULET_AUTOPLAY"] == "1",
                      let ratingKey = env["RIVULET_AUTOPLAY_KEY"] else { return }

                let testDuration = TimeInterval(env["RIVULET_AUTOPLAY_DURATION"] ?? "45") ?? 45
                let skipLifecycle = env["RIVULET_AUTOPLAY_SKIP_LIFECYCLE"] == "1"
                let startOffset: TimeInterval? = env["RIVULET_AUTOPLAY_OFFSET"].flatMap { TimeInterval($0) }

                hasLaunched = true
                print("[AutoPlay] Starting: ratingKey=\(ratingKey) duration=\(testDuration)s skipLifecycle=\(skipLifecycle) offset=\(startOffset.map { String(format: "%.0f", $0) } ?? "none")")

                // Wait for auth to be ready
                let authManager = PlexAuthManager.shared
                let deadline = Date().addingTimeInterval(30)
                while authManager.selectedServerURL == nil || authManager.selectedServerToken == nil {
                    if Date() > deadline {
                        print("[AutoPlay] ERROR: Auth not ready after 30s, aborting")
                        return
                    }
                    try? await Task.sleep(nanoseconds: 500_000_000)
                }

                guard let serverURL = authManager.selectedServerURL,
                      let authToken = authManager.selectedServerToken else {
                    print("[AutoPlay] ERROR: No server credentials")
                    return
                }

                // Fetch full metadata
                let networkManager = PlexNetworkManager.shared
                let metadata: PlexMetadata
                do {
                    metadata = try await networkManager.getFullMetadata(
                        serverURL: serverURL,
                        authToken: authToken,
                        ratingKey: ratingKey
                    )
                    print("[AutoPlay] Fetched: \(metadata.title ?? "Unknown") (\(metadata.type ?? "?"))")
                } catch {
                    print("[AutoPlay] ERROR: Failed to fetch metadata: \(error)")
                    return
                }

                // Log DV profile info
                let dvStream = metadata.Media?.first?.Part?.first?.Stream?.first(where: { $0.isDolbyVision })
                if let dvProfile = dvStream?.DOVIProfile {
                    print("[AutoPlay] DV Profile \(dvProfile), BL CompatID \(dvStream?.DOVIBLCompatID ?? -1)")
                }

                // Create viewModel and present player. Mirrors the real user
                // flow in TVSidebarView.presentPlayerForDeepLink so autoplay
                // tests exercise the same RPlayer UI (UniversalPlayerView +
                // PlayerContainerViewController) that users actually see.
                // Without this, autoplay presented NativePlayerViewController
                // (AVPlayerViewController) which waits on viewModel.$player —
                // but RPlayer never populates $player, so the screen sat on
                // the loading indicator while RPlayer decoded in the
                // background. See debugging notes 2026-04-11.
                await MainActor.run {
                    let viewModel = UniversalPlayerViewModel(
                        metadata: metadata,
                        serverURL: serverURL,
                        authToken: authToken,
                        startOffset: startOffset,
                        shuffledQueue: [],
                        loadingArtImage: nil,
                        loadingThumbImage: nil
                    )

                    let useApplePlayer = UserDefaults.standard.bool(forKey: "useApplePlayer")
                    let playerVC: UIViewController
                    if useApplePlayer {
                        playerVC = NativePlayerViewController(viewModel: viewModel)
                    } else {
                        let inputCoordinator = PlaybackInputCoordinator()
                        let playerView = UniversalPlayerView(
                            viewModel: viewModel,
                            inputCoordinator: inputCoordinator
                        )
                        playerVC = PlayerContainerViewController(
                            rootView: playerView,
                            viewModel: viewModel,
                            inputCoordinator: inputCoordinator
                        )
                    }

                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let rootVC = windowScene.windows.first?.rootViewController {
                        var topVC = rootVC
                        while let presented = topVC.presentedViewController {
                            topVC = presented
                        }
                        topVC.present(playerVC, animated: false)
                    }

                    // Schedule auto-stop after test duration
                    Task {
                        try? await Task.sleep(nanoseconds: UInt64(testDuration) * 1_000_000_000)
                        print("[AutoPlay] Test duration elapsed (\(testDuration)s), stopping")
                        viewModel.stopPlayback()
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let rootVC = windowScene.windows.first?.rootViewController {
                            rootVC.dismiss(animated: false)
                        }
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                        print("[AutoPlay] Test complete, exiting")
                        exit(0)
                    }
                }
            }
    }
}

// MARK: - macOS/iOS Split View Navigation

struct NavigationSplitViewContent: View {
    @State private var selectedSection: SidebarSection? = .settings

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedSection: $selectedSection)
        } detail: {
            switch selectedSection {
            case .plexSearch:
                PlexSearchView()
            case .plexHome:
                PlexHomeView()
            case .plexLibrary(let key, let title):
                PlexLibraryView(libraryKey: key, libraryTitle: title)
            case .liveTVChannels:
                ChannelListView()
            case .liveTVGuide:
                GuideLayoutView()
            case .settings:
                SettingsView()
            case .none:
                ContentUnavailableView(
                    "Select a Section",
                    systemImage: "tv",
                    description: Text("Choose from the sidebar to get started")
                )
            }
        }
    }
}

// MARK: - Placeholder Views (to be implemented in Phase 6)

struct EPGGridView: View {
    var body: some View {
        ContentUnavailableView(
            "TV Guide",
            systemImage: "calendar",
            description: Text("Electronic Program Guide will appear here")
        )
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            ServerConfiguration.self,
            PlexServer.self,
            IPTVSource.self,
            Channel.self,
            FavoriteChannel.self,
            WatchProgress.self,
            EPGProgram.self,
        ], inMemory: true)
}
