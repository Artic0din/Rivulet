//
//  ModelContainerFactoryTests.swift
//  RivuletTests
//
//  Reproduces audit finding C-1: a corrupt / un-migratable / unwritable
//  SwiftData store must NOT crash at launch. These tests drive the tiered
//  fallback in ModelContainerFactory through injected closures.
//

import XCTest
import SwiftData
@testable import Rivulet

final class ModelContainerFactoryTests: XCTestCase {

    /// A trivial standalone schema so the factory tests don't depend on the
    /// app's full model graph.
    @Model
    final class Probe {
        var value: Int
        init(value: Int) { self.value = value }
    }

    private func memorySchema() -> Schema { Schema([Probe.self]) }

    private func makeInMemoryContainer() throws -> ModelContainer {
        let config = ModelConfiguration(schema: memorySchema(), isStoredInMemoryOnly: true)
        return try ModelContainer(for: memorySchema(), configurations: [config])
    }

    private let dummyURL = URL(fileURLWithPath: "/tmp/rivulet-probe.store")

    struct OpenError: Error {}
    struct RemoveError: Error {}

    // MARK: - Tier 1

    func test_persistentOpensFirstTry_returnsPersistent() throws {
        var persistentCalls = 0
        let result = try ModelContainerFactory.build(
            storeURL: dummyURL,
            makePersistent: { _ in
                persistentCalls += 1
                return try self.makeInMemoryContainer()
            },
            makeInMemory: { XCTFail("in-memory should not be reached"); return try self.makeInMemoryContainer() },
            removeStoreFiles: { _ in XCTFail("store should not be reset") },
            diagnostics: { _, _ in XCTFail("no diagnostics on the happy path") }
        )
        XCTAssertEqual(result.resolution, .persistent)
        XCTAssertEqual(persistentCalls, 1)
    }

    // MARK: - Tier 2

    func test_corruptStore_resetAndRetry_recoversWithoutCrash() throws {
        var persistentCalls = 0
        var removeCalled = false
        var diagnostics: [String] = []

        let result = try ModelContainerFactory.build(
            storeURL: dummyURL,
            makePersistent: { _ in
                persistentCalls += 1
                // First open fails (corrupt store); after reset it succeeds.
                if persistentCalls == 1 { throw OpenError() }
                return try self.makeInMemoryContainer()
            },
            makeInMemory: { XCTFail("in-memory should not be reached"); return try self.makeInMemoryContainer() },
            removeStoreFiles: { url in
                removeCalled = true
                XCTAssertEqual(url, self.dummyURL)
            },
            diagnostics: { message, _ in diagnostics.append(message) }
        )

        XCTAssertEqual(result.resolution, .recoveredAfterReset)
        XCTAssertEqual(persistentCalls, 2, "should retry exactly once after reset")
        XCTAssertTrue(removeCalled, "store files must be deleted before retry")
        XCTAssertEqual(diagnostics.count, 1, "the first failure should be reported once")
    }

    // MARK: - Tier 3

    func test_persistentUnrecoverable_fallsBackToInMemory() throws {
        var persistentCalls = 0
        var inMemoryCalled = false
        var diagnostics: [String] = []

        let result = try ModelContainerFactory.build(
            storeURL: dummyURL,
            makePersistent: { _ in
                persistentCalls += 1
                throw OpenError()
            },
            makeInMemory: {
                inMemoryCalled = true
                return try self.makeInMemoryContainer()
            },
            removeStoreFiles: { _ in },
            diagnostics: { message, _ in diagnostics.append(message) }
        )

        XCTAssertEqual(result.resolution, .inMemoryFallback)
        XCTAssertEqual(persistentCalls, 2, "tries original then once after reset")
        XCTAssertTrue(inMemoryCalled)
        XCTAssertEqual(diagnostics.count, 2, "both persistent failures reported")
    }

    func test_resetThrows_stillFallsBackToInMemory() throws {
        var inMemoryCalled = false
        let result = try ModelContainerFactory.build(
            storeURL: dummyURL,
            makePersistent: { _ in throw OpenError() },
            makeInMemory: {
                inMemoryCalled = true
                return try self.makeInMemoryContainer()
            },
            removeStoreFiles: { _ in throw RemoveError() },
            diagnostics: { _, _ in }
        )
        XCTAssertEqual(result.resolution, .inMemoryFallback)
        XCTAssertTrue(inMemoryCalled)
    }

    func test_everythingFails_throwsInsteadOfCrashing() {
        XCTAssertThrowsError(
            try ModelContainerFactory.build(
                storeURL: dummyURL,
                makePersistent: { _ in throw OpenError() },
                makeInMemory: { throw OpenError() },
                removeStoreFiles: { _ in },
                diagnostics: { _, _ in }
            )
        ) { error in
            guard case ModelContainerFactoryError.inMemoryFallbackFailed = error else {
                return XCTFail("expected inMemoryFallbackFailed, got \(error)")
            }
        }
    }

    // MARK: - Store file removal

    func test_defaultRemoveStoreFiles_deletesStoreAndWalSiblings() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appending(path: "rivulet-c1-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let storeURL = dir.appending(path: "default.store")
        let siblings = ModelContainerFactory.storeSiblingURLs(for: storeURL)
        for url in siblings {
            try Data("x".utf8).write(to: url)
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        }

        try ModelContainerFactory.defaultRemoveStoreFiles(storeURL)

        for url in siblings {
            XCTAssertFalse(FileManager.default.fileExists(atPath: url.path), "\(url.lastPathComponent) should be deleted")
        }
    }

    func test_defaultRemoveStoreFiles_isNoOpWhenAbsent() throws {
        let storeURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appending(path: "rivulet-absent-\(UUID().uuidString).store")
        XCTAssertNoThrow(try ModelContainerFactory.defaultRemoveStoreFiles(storeURL))
    }
}
