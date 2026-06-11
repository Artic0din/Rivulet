//
//  ModelContainerFactory.swift
//  Rivulet
//
//  Builds the app's SwiftData ModelContainer with a tiered fallback so a
//  corrupt, un-migratable, or unwritable on-disk store can never brick launch.
//  Replaces the previous `fatalError` (audit finding C-1): a single throw at
//  app-init time turned any store problem into a permanent launch crash that
//  could only be cleared by reinstalling (losing all watch progress).
//

import Foundation
import SwiftData

/// Outcome of building the persistent store, so the UI can surface a non-fatal
/// notice when local history had to be reset or kept only in memory.
enum ModelStoreResolution: Equatable {
    /// The persistent store opened normally on the first attempt.
    case persistent
    /// The persistent store was corrupt/un-migratable; the on-disk files were
    /// deleted and a fresh persistent store was created. Local history was lost.
    case recoveredAfterReset
    /// The persistent store could not be opened or recreated; the app is
    /// running on an in-memory store. Nothing is persisted across launches.
    case inMemoryFallback
}

/// Result of a container build: the container plus how it was obtained.
struct ModelContainerBuildResult {
    let container: ModelContainer
    let resolution: ModelStoreResolution
}

/// Builds a ``ModelContainer`` with graceful degradation.
///
/// Pure and side-effect-injected so the fallback logic is unit-testable without
/// touching real SwiftData internals: the caller supplies the store URL, a
/// closure that constructs a persistent container (so a test can make it throw),
/// a closure that constructs an in-memory container, and the file-removal hook.
enum ModelContainerFactory {

    /// Sink for diagnostics. The app routes this to Sentry; tests capture it.
    typealias DiagnosticSink = (_ message: String, _ error: Error) -> Void

    /// Builds the container, applying the C-1 tiered fallback.
    ///
    /// - Parameters:
    ///   - storeURL: location of the persistent store file (`.store`). Its
    ///     `-shm`/`-wal` siblings are derived from it on reset.
    ///   - makePersistent: constructs a persistent container at `storeURL`.
    ///     Throws if the store is corrupt/un-migratable/unwritable.
    ///   - makeInMemory: constructs an in-memory container (last resort).
    ///   - removeStoreFiles: deletes the store file and its `-shm`/`-wal`
    ///     siblings. Must not throw for "already absent".
    ///   - diagnostics: receives a message + error for each recoverable failure.
    /// - Returns: the container and the resolution describing how it was built.
    /// - Throws: ``ModelContainerFactoryError/inMemoryFallbackFailed`` only when
    ///   even the in-memory store cannot be created — an unrecoverable
    ///   environment, surfaced to the caller rather than crashed on.
    static func build(
        storeURL: URL,
        makePersistent: (URL) throws -> ModelContainer,
        makeInMemory: () throws -> ModelContainer,
        removeStoreFiles: (URL) throws -> Void,
        diagnostics: DiagnosticSink
    ) throws -> ModelContainerBuildResult {
        // Tier 1: persistent store as-is.
        do {
            let container = try makePersistent(storeURL)
            return ModelContainerBuildResult(container: container, resolution: .persistent)
        } catch {
            diagnostics("ModelContainer persistent open failed; attempting store reset", error)
        }

        // Tier 2: delete the on-disk store and retry once. A corrupt or
        // un-migratable store recovers here at the cost of local history.
        do {
            try removeStoreFiles(storeURL)
            let container = try makePersistent(storeURL)
            return ModelContainerBuildResult(container: container, resolution: .recoveredAfterReset)
        } catch {
            diagnostics("ModelContainer reset+retry failed; falling back to in-memory store", error)
        }

        // Tier 3: in-memory store. The app stays usable for this session even
        // if the disk is full or unwritable; nothing persists across launches.
        do {
            let container = try makeInMemory()
            return ModelContainerBuildResult(container: container, resolution: .inMemoryFallback)
        } catch {
            diagnostics("ModelContainer in-memory fallback failed", error)
            throw ModelContainerFactoryError.inMemoryFallbackFailed(error)
        }
    }

    /// Deletes the SwiftData store file and its write-ahead-log siblings.
    /// "File does not exist" is treated as success; other I/O errors propagate.
    static func defaultRemoveStoreFiles(_ storeURL: URL) throws {
        let manager = FileManager.default
        for url in storeSiblingURLs(for: storeURL) where manager.fileExists(atPath: url.path) {
            try manager.removeItem(at: url)
        }
    }

    /// The store file plus its `-shm` and `-wal` companions.
    static func storeSiblingURLs(for storeURL: URL) -> [URL] {
        let base = storeURL.path
        return [storeURL,
                URL(fileURLWithPath: base + "-shm"),
                URL(fileURLWithPath: base + "-wal")]
    }
}

/// Error thrown only when even the in-memory last resort fails.
enum ModelContainerFactoryError: Error {
    case inMemoryFallbackFailed(Error)
}
