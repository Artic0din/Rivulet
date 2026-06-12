//
//  PlexWatchlistServiceTests.swift
//  RivuletTests
//

import XCTest
@testable import Rivulet

@MainActor
final class PlexWatchlistServiceTests: XCTestCase {

    func testOptimisticAddRevertsOnFailure() async {
        let api = StubWatchlistAPI()
        api.shouldFailWrites = true

        let service = PlexWatchlistService(api: api, cache: NullWatchlistCache())
        await service.add(guid: "tmdb://1", item: makeItem(id: "1"))

        // After failure, the GUID should not be in the set.
        XCTAssertFalse(service.watchlistGUIDs.contains("tmdb://1"))
    }

    func testOptimisticAddPersistsOnSuccess() async {
        let api = StubWatchlistAPI()
        let service = PlexWatchlistService(api: api, cache: NullWatchlistCache())

        await service.add(guid: "tmdb://1", item: makeItem(id: "1"))

        XCTAssertTrue(service.watchlistGUIDs.contains("tmdb://1"))
        XCTAssertEqual(service.watchlistItems.count, 1)
    }

    func testOptimisticRemovePutsItBackOnFailure() async {
        let api = StubWatchlistAPI()
        let service = PlexWatchlistService(api: api, cache: NullWatchlistCache())
        await service.add(guid: "tmdb://1", item: makeItem(id: "1"))

        api.shouldFailWrites = true
        await service.remove(guid: "tmdb://1")

        XCTAssertTrue(service.watchlistGUIDs.contains("tmdb://1"))
        XCTAssertEqual(service.watchlistItems.count, 1)
    }

    func testFetchWatchlistPopulatesState() async {
        let api = StubWatchlistAPI()
        api.fetchResult = [makeItem(id: "9", guid: "tmdb://9")]

        let service = PlexWatchlistService(api: api, cache: NullWatchlistCache())
        await service.fetchWatchlist()

        XCTAssertEqual(service.watchlistItems.count, 1)
        XCTAssertTrue(service.watchlistGUIDs.contains("tmdb://9"))
    }

    func testFetchWatchlistProviderFailurePreservesCachedState() async {
        let cachedItem = makeItem(id: "cached", guid: "tmdb://42")
        let api = StubWatchlistAPI()
        api.fetchError = URLError(.cannotConnectToHost)

        let service = PlexWatchlistService(api: api, cache: RecordingWatchlistCache(initialItems: [cachedItem]))
        await service.fetchWatchlist(force: true)

        XCTAssertEqual(service.watchlistItems, [cachedItem])
        XCTAssertTrue(service.watchlistGUIDs.contains("tmdb://42"))
        XCTAssertNotNil(service.lastFetchError)
        XCTAssertNil(service.transientWriteError)
    }

    func testProviderHTTPErrorRedactsTokenBearingBodySnippet() {
        let error = PlexWatchlistHTTPError(
            statusCode: 500,
            bodySnippet: #"upstream failed url=https://discover.provider.plex.tv/actions/addToWatchlist?ratingKey=1&X-Plex-Token=secret-token"#
        )

        XCTAssertFalse(error.localizedDescription.contains("secret-token"))
        XCTAssertFalse(error.localizedDescription.contains("X-Plex-Token=secret-token"))
        XCTAssertTrue(error.localizedDescription.contains("X-Plex-Token=REDACTED"))
    }

    func testProviderWritesUseAccountTokenProviderOnly() async {
        let api = StubWatchlistAPI()
        let service = PlexWatchlistService(
            api: api,
            cache: NullWatchlistCache(),
            tokenProvider: { "account-token" }
        )

        await service.add(guid: "tmdb://1", item: makeItem(id: "1"))
        await service.remove(guid: "tmdb://1")

        XCTAssertEqual(api.addTokens, ["account-token"])
        XCTAssertEqual(api.removeTokens, ["account-token"])
    }

    func testWriteFailureSurfacesRecoverableSecretSafeMessage() async {
        let api = StubWatchlistAPI()
        api.writeError = PlexWatchlistHTTPError(
            statusCode: 503,
            bodySnippet: #"provider failed https://metadata.provider.plex.tv/library/metadata/matches?guid=tmdb://1&X-Plex-Token=secret-token"#
        )
        let service = PlexWatchlistService(api: api, cache: NullWatchlistCache())

        await service.add(guid: "tmdb://1", item: makeItem(id: "1"))

        XCTAssertEqual(service.transientWriteError, "Couldn't update Watchlist")
        XCTAssertFalse(service.lastFetchError?.localizedDescription.contains("secret-token") ?? true)
    }

    func testContainsTmdbIdMatchesGuid() async {
        let api = StubWatchlistAPI()
        let service = PlexWatchlistService(api: api, cache: NullWatchlistCache())
        await service.add(guid: "tmdb://42", item: makeItem(id: "42", guid: "tmdb://42"))

        XCTAssertTrue(service.contains(tmdbId: 42))
        XCTAssertFalse(service.contains(tmdbId: 43))
    }

    func testResetClearsState() async {
        let api = StubWatchlistAPI()
        let service = PlexWatchlistService(api: api, cache: NullWatchlistCache())
        await service.add(guid: "tmdb://1", item: makeItem(id: "1"))

        service.reset()

        XCTAssertTrue(service.watchlistItems.isEmpty)
        XCTAssertTrue(service.watchlistGUIDs.isEmpty)
    }

    func testRemoveClearsAllGuidsForItem() async {
        let api = StubWatchlistAPI()
        let service = PlexWatchlistService(api: api, cache: NullWatchlistCache())

        let multiGuidItem = PlexWatchlistItem(
            id: "1",
            title: "Multi",
            year: 2024,
            type: .movie,
            posterURL: nil,
            guids: ["tmdb://42", "imdb://tt123", "tvdb://999"]
        )
        await service.add(guid: "tmdb://42", item: multiGuidItem)
        XCTAssertTrue(service.watchlistGUIDs.contains("imdb://tt123"))

        await service.remove(guid: "tmdb://42")

        XCTAssertFalse(service.watchlistGUIDs.contains("tmdb://42"))
        XCTAssertFalse(service.watchlistGUIDs.contains("imdb://tt123"))
        XCTAssertFalse(service.watchlistGUIDs.contains("tvdb://999"))
        XCTAssertTrue(service.watchlistItems.isEmpty)
    }

    private func makeItem(id: String, guid: String = "tmdb://1") -> PlexWatchlistItem {
        PlexWatchlistItem(
            id: id,
            title: "Test",
            year: 2024,
            type: .movie,
            posterURL: nil,
            guids: [guid]
        )
    }
}

// MARK: - Stubs

final class StubWatchlistAPI: PlexWatchlistAPIProtocol, @unchecked Sendable {
    var shouldFailWrites = false
    var fetchError: Error?
    var writeError: Error?
    var fetchResult: [PlexWatchlistItem] = []
    var fetchTokens: [String] = []
    var addTokens: [String] = []
    var removeTokens: [String] = []

    func fetchAll(token: String) async throws -> [PlexWatchlistItem] {
        fetchTokens.append(token)
        if let fetchError { throw fetchError }
        return fetchResult
    }

    func add(guids: [String], token: String) async throws {
        addTokens.append(token)
        if let writeError { throw writeError }
        if shouldFailWrites { throw URLError(.notConnectedToInternet) }
    }

    func remove(guid: String, token: String) async throws {
        removeTokens.append(token)
        if let writeError { throw writeError }
        if shouldFailWrites { throw URLError(.notConnectedToInternet) }
    }
}

final class NullWatchlistCache: WatchlistCacheProtocol {
    func load() -> [PlexWatchlistItem]? { nil }
    func save(_ items: [PlexWatchlistItem]) {}
    func clear() {}
}

final class RecordingWatchlistCache: WatchlistCacheProtocol, @unchecked Sendable {
    private let initialItems: [PlexWatchlistItem]?
    private(set) var savedItems: [PlexWatchlistItem]?
    private(set) var didClear = false

    init(initialItems: [PlexWatchlistItem]? = nil) {
        self.initialItems = initialItems
    }

    func load() -> [PlexWatchlistItem]? { initialItems }

    func save(_ items: [PlexWatchlistItem]) {
        savedItems = items
    }

    func clear() {
        didClear = true
    }
}
