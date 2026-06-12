//
//  RivuletApp.swift
//  Rivulet
//
//  Created by Bain Gurley on 11/28/25.
//

import SwiftUI
import SwiftData
import Sentry

// MARK: - App Delegate

class RivuletAppDelegate: NSObject, UIApplicationDelegate {

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        Task {
            await DeepLinkHandler.shared.handle(url: url)
        }
        return true
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([any UIUserActivityRestoring]?) -> Void) -> Bool {
        guard let ratingKey = userActivity.userInfo?["ratingKey"] as? String,
              !ratingKey.isEmpty else { return false }

        switch userActivity.activityType {
        case "com.rivulet.viewMedia":
            Task {
                await DeepLinkHandler.shared.handle(
                    url: URL(string: "rivulet://detail?ratingKey=\(ratingKey)")!
                )
            }
            return true
        case "com.rivulet.playMedia":
            Task {
                await DeepLinkHandler.shared.handle(
                    url: URL(string: "rivulet://play?ratingKey=\(ratingKey)")!
                )
            }
            return true
        default:
            return false
        }
    }
}

// MARK: - App

@main
struct RivuletApp: App {
    @UIApplicationDelegateAdaptor(RivuletAppDelegate.self) var appDelegate

    init() {
        #if !DEBUG
        SentrySDK.start { options in
            options.dsn = Secrets.sentryDSN
            options.debug = false
            options.tracesSampleRate = 1.0
            options.attachStacktrace = true
            options.enableAutoSessionTracking = true
            options.enableCaptureFailedRequests = true
            options.enableSwizzling = true
            options.enableAppHangTracking = true
            options.appHangTimeoutInterval = 2

            options.beforeSend = { event in
                // Drop cancelled URL request errors — these are normal when navigating away
                if let exceptions = event.exceptions,
                   exceptions.contains(where: { $0.value?.contains("Code=-999") == true || $0.value?.contains("cancelled") == true }) {
                    return nil
                }
                if let message = event.message?.formatted,
                   message.contains("Code=-999") || (message.contains("NSURLErrorDomain") && message.contains("cancelled")) {
                    return nil
                }
                return RivuletApp.sanitizeSentryEvent(event)
            }
        }
        #endif

        // NowPlayingService disabled — AVPlayerViewController handles Now Playing natively.
        // NowPlayingService.shared.initialize()
    }

    private nonisolated static func sanitizeSentryEvent(_ event: Event) -> Event {
        if let tags = event.tags {
            event.tags = SensitiveDataRedactor.redact(headers: tags)
        }
        if let extra = event.extra {
            event.extra = SensitiveDataRedactor.redact(metadata: extra)
        }
        if let context = event.context {
            event.context = context.reduce(into: [:]) { result, entry in
                result[entry.key] = SensitiveDataRedactor.redact(metadata: entry.value)
            }
        }
        if let breadcrumbs = event.breadcrumbs {
            breadcrumbs.forEach { breadcrumb in
                breadcrumb.message = SensitiveDataRedactor.redact(breadcrumb.message)
                if let data = breadcrumb.data {
                    breadcrumb.data = SensitiveDataRedactor.redact(metadata: data)
                }
            }
        }
        if let exceptions = event.exceptions {
            exceptions.forEach { exception in
                exception.value = SensitiveDataRedactor.redact(exception.value)
            }
        }
        if let message = event.message {
            message.message = SensitiveDataRedactor.redact(message.message)
        }
        if let request = event.request {
            request.url = SensitiveDataRedactor.redact(request.url)
            request.queryString = SensitiveDataRedactor.redact(request.queryString)
            if let headers = request.headers {
                request.headers = SensitiveDataRedactor.redact(headers: headers)
            }
        }
        return event
    }

    private let modelStore = RivuletApp.buildModelContainer()

    /// Builds the shared container via ``ModelContainerFactory`` so a corrupt or
    /// un-migratable store degrades gracefully (reset → in-memory) instead of
    /// crashing at launch. See audit finding C-1.
    private static func buildModelContainer() -> ModelContainerBuildResult {
        let schema = Schema([
            ServerConfiguration.self,
            PlexServer.self,
            IPTVSource.self,
            Channel.self,
            FavoriteChannel.self,
            WatchProgress.self,
            EPGProgram.self,
        ])

        // SwiftData's default persistent store lives at
        // Application Support/default.store.
        let storeURL = URL.applicationSupportDirectory.appending(path: "default.store")

        let diagnostics: ModelContainerFactory.DiagnosticSink = { message, error in
            #if !DEBUG
            SentrySDK.capture(message: message) { scope in
                scope.setExtra(value: "\(error)", key: "underlyingError")
            }
            #else
            print("[ModelContainer] \(message): \(error)")
            #endif
        }

        do {
            return try ModelContainerFactory.build(
                storeURL: storeURL,
                makePersistent: { url in
                    let config = ModelConfiguration(schema: schema, url: url, allowsSave: true)
                    return try ModelContainer(for: schema, configurations: [config])
                },
                makeInMemory: {
                    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                    return try ModelContainer(for: schema, configurations: [config])
                },
                removeStoreFiles: ModelContainerFactory.defaultRemoveStoreFiles,
                diagnostics: diagnostics
            )
        } catch {
            // Only reached if even the in-memory store cannot be created — an
            // unrecoverable runtime environment. There is no usable container to
            // hand SwiftUI, so this is the one genuinely fatal path.
            diagnostics("ModelContainer build exhausted all fallbacks", error)
            fatalError("Could not create any ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(storeResolution: modelStore.resolution)
                .environment(MediaProviderRegistry.shared)
                .environment(MusicProviderRegistry.shared)
                .environment(MetadataSourceRegistry.shared)
        }
        .modelContainer(modelStore.container)
    }
}
