//
//  PlexProviderBoundaryTests.swift
//  RivuletTests
//
//  Tests for Epic 1 provider abstraction ownership boundaries.
//

import XCTest
@testable import Rivulet

@MainActor
final class PlexProviderBoundaryTests: XCTestCase {
    func testWatchlistReadUsesInjectedAccountTokenBoundaryForTMDBRefs() async {
        let watchlist = StubPlexWatchlistManager(containedTMDBIDs: [42])
        let provider = makeProvider(watchlistService: watchlist)

        let result = await provider.isOnWatchlist(
            MediaItemRef(providerID: TMDBMediaMapper.providerID, itemID: "movie:42")
        )

        XCTAssertTrue(result)
        XCTAssertEqual(watchlist.containsCalls, [42])
    }

    func testWatchlistReadDoesNotAskDiscoverBoundaryForPlexRefsWithoutResolvedGUIDs() async {
        let watchlist = StubPlexWatchlistManager(containedTMDBIDs: [42])
        let provider = makeProvider(watchlistService: watchlist)

        let result = await provider.isOnWatchlist(
            MediaItemRef(providerID: provider.id, itemID: "12345")
        )

        XCTAssertFalse(result)
        XCTAssertTrue(watchlist.containsCalls.isEmpty)
    }

    func testProviderWatchlistWritesRemainExplicitlyUnsupportedForRefOnlyCalls() async {
        let provider = makeProvider()
        let ref = MediaItemRef(providerID: TMDBMediaMapper.providerID, itemID: "movie:42")

        do {
            try await provider.addToWatchlist(ref)
            XCTFail("Expected addToWatchlist to fail at the provider boundary")
        } catch MediaProviderError.backendSpecific(let message) {
            XCTAssertEqual(message, PlexProviderBoundaryPolicy.refOnlyWatchlistWriteUnsupportedMessage)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        do {
            try await provider.removeFromWatchlist(ref)
            XCTFail("Expected removeFromWatchlist to fail at the provider boundary")
        } catch MediaProviderError.backendSpecific(let message) {
            XCTAssertEqual(message, PlexProviderBoundaryPolicy.refOnlyWatchlistWriteUnsupportedMessage)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testProviderBoundaryPolicyDocumentsEndpointOwnersAndCredentialScopes() {
        XCTAssertEqual(PlexProviderBoundaryPolicy.adapterOwner, "PlexProvider / MediaProvider adapter")
        XCTAssertTrue(PlexProviderBoundaryPolicy.watchlistReadBoundary.contains("PlexWatchlistService"))
        XCTAssertTrue(PlexProviderBoundaryPolicy.watchlistWriteBoundary.contains("account token"))
        XCTAssertTrue(PlexProviderBoundaryPolicy.watchStateBoundary.contains("PlexWatchStateRequestFactory"))
        XCTAssertTrue(PlexProviderBoundaryPolicy.corePMSBoundary.contains("selected server token"))
    }

    private func makeProvider(
        watchlistService: (any PlexWatchlistManaging)? = nil
    ) -> PlexProvider {
        PlexProvider(
            machineIdentifier: "machine-1",
            displayName: "Library",
            serverURL: "https://plex.example",
            authToken: "selected-server-token",
            watchlistService: watchlistService ?? StubPlexWatchlistManager()
        )
    }
}

@MainActor
private final class StubPlexWatchlistManager: PlexWatchlistManaging {
    private let containedTMDBIDs: Set<Int>
    private(set) var containsCalls: [Int] = []

    init(containedTMDBIDs: Set<Int> = []) {
        self.containedTMDBIDs = containedTMDBIDs
    }

    func contains(tmdbId: Int) -> Bool {
        containsCalls.append(tmdbId)
        return containedTMDBIDs.contains(tmdbId)
    }
}
