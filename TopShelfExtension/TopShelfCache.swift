//
//  TopShelfCache.swift
//  TopShelfExtension
//
//  Read-only Top Shelf cache access for the TV Services Extension.
//
//  DUPLICATE of the read side of `Rivulet/Services/Cache/TopShelfCache.swift`
//  (extensions cannot import the app module). The extension only READS the
//  secret-free payload and resolves opaque image filenames to local files in the
//  App Group container. It never writes the payload, fetches authenticated
//  remote images, or handles tokens.
//

import Foundation
import os

private let topShelfCacheLog = Logger(subsystem: "com.gstudios.rivulet.TopShelfExtension", category: "TopShelfCache")

final class TopShelfCache: Sendable {
    static let shared = TopShelfCache()

    private let appGroupIdentifier = "group.com.bain.Rivulet"
    private let imagesDirectoryName = "TopShelfImages"

    private init() {}

    private var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    private let userDefaultsKey = "topShelfItems"

    // MARK: - Read

    func readItems() -> [TopShelfItem] {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: userDefaultsKey) else {
            return []
        }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([TopShelfItem].self, from: data)
        } catch {
            topShelfCacheLog.error("TopShelf: failed to decode items")
            return []
        }
    }

    // MARK: - Image Handoff (local files only)

    private var imagesDirectoryURL: URL? {
        containerURL?.appendingPathComponent(imagesDirectoryName, isDirectory: true)
    }

    /// Resolve an opaque payload filename to a local file URL. Rejects
    /// path-traversal / nested names. Returns nil if the file does not exist.
    func imageFileURL(forFileName fileName: String) -> URL? {
        guard isSafeFileName(fileName), let dir = imagesDirectoryURL else { return nil }
        let url = dir.appendingPathComponent(fileName, isDirectory: false)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private func isSafeFileName(_ name: String) -> Bool {
        !name.isEmpty && !name.contains("/") && !name.contains("\\") && name != "." && name != ".." && !name.contains("..")
    }
}
