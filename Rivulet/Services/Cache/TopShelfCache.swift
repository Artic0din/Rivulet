//
//  TopShelfCache.swift
//  Rivulet
//
//  Manages shared cache for Top Shelf extension via App Groups.
//
//  SECURITY (E2-PR2 / NET-019): the payload written here is secret-free. Artwork
//  is handed off as local files in the App Group `TopShelfImages` directory whose
//  bytes the app fetched under its own authenticated session; the payload stores
//  only opaque filenames. No token-bearing URL is written, logged, or shared.
//  Diagnostics use `Logger` with counts only — never URLs, titles, or payloads.
//

import Foundation
import os

private let topShelfCacheLog = Logger(subsystem: "com.rivulet.app", category: "TopShelf")

/// Manages read/write access to Top Shelf data in the shared App Group container.
/// Used by both the main app (write) and TV Services Extension (read).
final class TopShelfCache: Sendable {
    static let shared = TopShelfCache()

    private let appGroupIdentifier = "group.com.bain.Rivulet"
    private let imagesDirectoryName = "TopShelfImages"

    private init() {}

    // MARK: - Container Access

    private var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    private let userDefaultsKey = "topShelfItems"

    // MARK: - Write (Main App)

    /// Write Top Shelf items to the shared container.
    /// Called by PlexDataStore when Continue Watching data is refreshed.
    func writeItems(_ items: [TopShelfItem]) {
        guard let defaults = sharedDefaults else {
            topShelfCacheLog.error("TopShelf: App Group UserDefaults unavailable on write")
            return
        }

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(items)
            defaults.set(data, forKey: userDefaultsKey)
            topShelfCacheLog.info("TopShelf: wrote \(items.count) items")
        } catch {
            topShelfCacheLog.error("TopShelf: failed to encode items")
        }
    }

    // MARK: - Read (Extension / app)

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

    // MARK: - Image Handoff (secret-free local files)

    private var imagesDirectoryURL: URL? {
        containerURL?.appendingPathComponent(imagesDirectoryName, isDirectory: true)
    }

    /// Resolve an opaque payload filename to a local file URL inside the App
    /// Group images directory. Rejects path-traversal / nested names.
    func imageFileURL(forFileName fileName: String) -> URL? {
        guard isSafeFileName(fileName), let dir = imagesDirectoryURL else { return nil }
        return dir.appendingPathComponent(fileName, isDirectory: false)
    }

    /// Write fetched image bytes to the App Group images directory and return the
    /// opaque filename to store in the payload, or nil on failure (caller falls
    /// back to no image). `ratingKey` is a non-secret identifier.
    @discardableResult
    func writeImageData(_ data: Data, for ratingKey: String) -> String? {
        let fileName = "\(sanitizedComponent(ratingKey)).jpg"
        guard isSafeFileName(fileName),
              let dir = imagesDirectoryURL else { return nil }
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try data.write(to: dir.appendingPathComponent(fileName, isDirectory: false), options: .atomic)
            return fileName
        } catch {
            topShelfCacheLog.error("TopShelf: failed to write image file")
            return nil
        }
    }

    /// Delete any cached image files not referenced by the current payload.
    func pruneImages(keepingFileNames keep: [String]) {
        guard let dir = imagesDirectoryURL else { return }
        let keepSet = Set(keep)
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        for file in files where !keepSet.contains(file.lastPathComponent) {
            try? fm.removeItem(at: file)
        }
    }

    private func removeAllImages() {
        guard let dir = imagesDirectoryURL else { return }
        try? FileManager.default.removeItem(at: dir)
    }

    // MARK: - Filename safety

    /// A safe leaf filename: no path separators, no parent refs, non-empty.
    private func isSafeFileName(_ name: String) -> Bool {
        !name.isEmpty && !name.contains("/") && !name.contains("\\") && name != "." && name != ".." && !name.contains("..")
    }

    private func sanitizedComponent(_ raw: String) -> String {
        let allowed = CharacterSet.alphanumerics
        let mapped = raw.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }
        let result = String(mapped)
        return result.isEmpty ? "item" : result
    }

    // MARK: - Clear

    /// Remove all cached Top Shelf items and their image files (on sign out).
    func clear() {
        sharedDefaults?.removeObject(forKey: userDefaultsKey)
        removeAllImages()
    }
}
