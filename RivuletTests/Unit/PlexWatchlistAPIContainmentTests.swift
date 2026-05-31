//
//  PlexWatchlistAPIContainmentTests.swift
//  RivuletTests
//
//  Tests for Discover/provider watchlist endpoint containment.
//

import XCTest
@testable import Rivulet

final class PlexWatchlistAPIContainmentTests: XCTestCase {
    override func tearDown() {
        WatchlistProviderURLProtocol.reset()
        super.tearDown()
    }

    func testFetchUsesDiscoverProviderWithRetainedAccountQueryToken() async throws {
        let response = """
        {
          "MediaContainer": {
            "Metadata": [
              {
                "ratingKey": "discover-1",
                "title": "Known",
                "year": 2024,
                "type": "movie",
                "thumb": "https://metadata-static.plex.tv/poster.jpg",
                "Guid": [{ "id": "tmdb://1" }]
              }
            ]
          }
        }
        """
        WatchlistProviderURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.host, "discover.provider.plex.tv")
            XCTAssertEqual(request.url?.path, "/library/sections/watchlist/all")
            XCTAssertEqual(request.queryValue("includeGuids"), "1")
            XCTAssertEqual(request.queryValue("X-Plex-Token"), "account-token")
            XCTAssertNil(request.value(forHTTPHeaderField: "X-Plex-Token"))
            return (HTTPURLResponse.ok(for: request), Data(response.utf8))
        }

        let api = PlexWatchlistAPI(session: makeSession())
        let items = try await api.fetchAll(token: "account-token")

        XCTAssertEqual(items.map(\.id), ["discover-1"])
        XCTAssertEqual(WatchlistProviderURLProtocol.requests.count, 1)
    }

    func testAddResolvesMetadataProviderMatchThenUsesDiscoverActionEndpoint() async throws {
        let matchResponse = """
        { "MediaContainer": { "Metadata": [{ "ratingKey": "discover-rating-key" }] } }
        """
        WatchlistProviderURLProtocol.handler = { request in
            switch (request.url?.host, request.url?.path, request.httpMethod) {
            case ("metadata.provider.plex.tv", "/library/metadata/matches", _):
                XCTAssertEqual(request.queryValue("type"), "1")
                XCTAssertEqual(request.queryValue("guid"), "tmdb://1")
                XCTAssertEqual(request.queryValue("X-Plex-Token"), "account-token")
                return (HTTPURLResponse.ok(for: request), Data(matchResponse.utf8))
            case ("discover.provider.plex.tv", "/actions/addToWatchlist", "PUT"):
                XCTAssertEqual(request.queryValue("ratingKey"), "discover-rating-key")
                XCTAssertEqual(request.queryValue("X-Plex-Token"), "account-token")
                return (HTTPURLResponse.ok(for: request), Data())
            default:
                XCTFail("Unexpected request: \(request)")
                return (HTTPURLResponse(statusCode: 500, for: request), Data())
            }
        }

        let api = PlexWatchlistAPI(session: makeSession())
        try await api.add(guids: ["tmdb://1"], token: "account-token")

        XCTAssertEqual(WatchlistProviderURLProtocol.requests.map { $0.url?.host }, [
            "metadata.provider.plex.tv",
            "discover.provider.plex.tv"
        ])
    }

    func testRemoveUsesMetadataProviderMatchThenDiscoverActionEndpoint() async throws {
        let matchResponse = """
        { "MediaContainer": { "Metadata": [{ "ratingKey": "discover-rating-key" }] } }
        """
        WatchlistProviderURLProtocol.handler = { request in
            switch (request.url?.host, request.url?.path, request.httpMethod) {
            case ("metadata.provider.plex.tv", "/library/metadata/matches", _):
                return (HTTPURLResponse.ok(for: request), Data(matchResponse.utf8))
            case ("discover.provider.plex.tv", "/actions/removeFromWatchlist", "PUT"):
                XCTAssertEqual(request.queryValue("ratingKey"), "discover-rating-key")
                XCTAssertEqual(request.queryValue("X-Plex-Token"), "account-token")
                return (HTTPURLResponse.ok(for: request), Data())
            default:
                XCTFail("Unexpected request: \(request)")
                return (HTTPURLResponse(statusCode: 500, for: request), Data())
            }
        }

        let api = PlexWatchlistAPI(session: makeSession())
        try await api.remove(guid: "tmdb://1", token: "account-token")

        XCTAssertEqual(WatchlistProviderURLProtocol.requests.map { $0.url?.path }, [
            "/library/metadata/matches",
            "/actions/removeFromWatchlist"
        ])
    }

    func testMetadataProviderNoMatchThrowsRecoverableProviderErrorWithoutMutation() async throws {
        WatchlistProviderURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.host, "metadata.provider.plex.tv")
            let response = "{ \"MediaContainer\": { \"Metadata\": [] } }"
            return (HTTPURLResponse.ok(for: request), Data(response.utf8))
        }

        let api = PlexWatchlistAPI(session: makeSession())

        do {
            try await api.add(guids: ["tmdb://missing"], token: "account-token")
            XCTFail("Expected metadata match failure")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("No Plex Discover match"))
            XCTAssertFalse(error.localizedDescription.contains("account-token"))
        }

        XCTAssertEqual(WatchlistProviderURLProtocol.requests.count, 2)
        XCTAssertTrue(WatchlistProviderURLProtocol.requests.allSatisfy { $0.url?.host == "metadata.provider.plex.tv" })
    }

    func testProviderHTTPFailureRedactsTokenBearingResponseBody() async throws {
        WatchlistProviderURLProtocol.handler = { request in
            let body = "failed request https://discover.provider.plex.tv/library/sections/watchlist/all?X-Plex-Token=account-token"
            return (HTTPURLResponse(statusCode: 503, for: request), Data(body.utf8))
        }

        let api = PlexWatchlistAPI(session: makeSession())

        do {
            _ = try await api.fetchAll(token: "account-token")
            XCTFail("Expected provider HTTP failure")
        } catch {
            XCTAssertFalse(error.localizedDescription.contains("account-token"))
            XCTAssertTrue(error.localizedDescription.contains("X-Plex-Token=REDACTED"))
        }
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [WatchlistProviderURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private final class WatchlistProviderURLProtocol: URLProtocol, @unchecked Sendable {
    static var requests: [URLRequest] = []
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    static func reset() {
        requests = []
        handler = nil
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.requests.append(request)

        do {
            guard let handler = Self.handler else {
                throw URLError(.badServerResponse)
            }
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private extension URLRequest {
    func queryValue(_ name: String) -> String? {
        guard let url,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        return components.queryItems?.first(where: { $0.name == name })?.value
    }
}

private extension HTTPURLResponse {
    static func ok(for request: URLRequest) -> HTTPURLResponse {
        HTTPURLResponse(statusCode: 200, for: request)
    }

    convenience init(statusCode: Int, for request: URLRequest) {
        self.init(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
    }
}
