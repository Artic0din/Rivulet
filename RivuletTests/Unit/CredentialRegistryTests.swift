//
//  CredentialRegistryTests.swift
//  RivuletTests
//

import XCTest
@testable import Rivulet

@MainActor
final class CredentialRegistryTests: XCTestCase {
    private let testProviderID = "plex:credreg-test"

    override func tearDown() async throws {
        // Clean up any keychain residue from this test class
        await CredentialRegistry.shared.clearToken(for: .server(providerID: testProviderID))
        await CredentialRegistry.shared.clearToken(for: .serverUser(providerID: testProviderID, userID: "u1"))
        await CredentialRegistry.shared.clearToken(for: .serverUser(providerID: testProviderID, userID: "u2"))
        await CredentialRegistry.shared.clearToken(for: .plexAccount(accountID: "credreg-test-acct"))
        CredentialRegistry.shared.unregisterAccount(id: "credreg-test-acct")
        CredentialRegistry.shared.unregisterServer(providerID: testProviderID)
        try await super.tearDown()
    }

    func test_setAndGetToken_roundTrips() async throws {
        let registry = CredentialRegistry.shared
        let scope = CredentialScope.server(providerID: testProviderID)
        try await registry.setToken("abc-123", for: scope)
        XCTAssertEqual(registry.token(for: scope), "abc-123")
    }

    func test_clearToken_removesValue() async throws {
        let registry = CredentialRegistry.shared
        let scope = CredentialScope.server(providerID: testProviderID)
        try await registry.setToken("xyz", for: scope)
        await registry.clearToken(for: scope)
        XCTAssertNil(registry.token(for: scope))
    }

    func test_setToken_replacesExistingValue() async throws {
        let registry = CredentialRegistry.shared
        let scope = CredentialScope.server(providerID: testProviderID)

        try await registry.setToken("old-token", for: scope)
        try await registry.setToken("new-token", for: scope)

        XCTAssertEqual(registry.token(for: scope), "new-token")
    }

    func test_accountServerAndServerUserScopes_areDistinct() async throws {
        let registry = CredentialRegistry.shared
        let accountScope = CredentialScope.plexAccount(accountID: "credreg-test-acct")
        let serverScope = CredentialScope.server(providerID: testProviderID)
        let userScope = CredentialScope.serverUser(providerID: testProviderID, userID: "u1")
        try await registry.setToken("account-token", for: accountScope)
        try await registry.setToken("server-token", for: serverScope)
        try await registry.setToken("user-token", for: userScope)
        XCTAssertEqual(registry.token(for: accountScope), "account-token")
        XCTAssertEqual(registry.token(for: serverScope), "server-token")
        XCTAssertEqual(registry.token(for: userScope), "user-token")
    }

    func test_clearRegisteredCredentials_clearsAccountServerAndHomeUserTokens() async throws {
        let registry = CredentialRegistry.shared
        let accountScope = CredentialScope.plexAccount(accountID: "credreg-test-acct")
        let serverScope = CredentialScope.server(providerID: testProviderID)
        let firstUserScope = CredentialScope.serverUser(providerID: testProviderID, userID: "u1")
        let secondUserScope = CredentialScope.serverUser(providerID: testProviderID, userID: "u2")

        registry.registerAccount(AccountCredential(id: "credreg-test-acct", displayName: "Test Account", kind: .plex))
        registry.registerServer(ServerCredential(id: testProviderID, displayName: "Test Server", userID: "u1", kind: .plex))
        registry.registerServerUser(providerID: testProviderID, userID: "u2")
        try await registry.setToken("account-token", for: accountScope)
        try await registry.setToken("server-token", for: serverScope)
        try await registry.setToken("home-user-token-1", for: firstUserScope)
        try await registry.setToken("home-user-token-2", for: secondUserScope)

        registry.clearRegisteredCredentials()

        XCTAssertNil(registry.token(for: accountScope))
        XCTAssertNil(registry.token(for: serverScope))
        XCTAssertNil(registry.token(for: firstUserScope))
        XCTAssertNil(registry.token(for: secondUserScope))
        XCTAssertTrue(registry.accounts.isEmpty)
        XCTAssertTrue(registry.serverCredentials.isEmpty)
        XCTAssertTrue(registry.serverUserCredentialScopes.isEmpty)
    }

    func test_registerServer_addsAndDedupesByProviderID() {
        let registry = CredentialRegistry.shared
        let cred = ServerCredential(id: testProviderID, displayName: "Test", userID: "u1", kind: .plex)
        let credUpdated = ServerCredential(id: testProviderID, displayName: "Renamed", userID: "u1", kind: .plex)
        registry.registerServer(cred)
        registry.registerServer(credUpdated)
        // Most recent registration wins; only one entry per providerID
        let matches = registry.serverCredentials.filter { $0.id == testProviderID }
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches.first?.displayName, "Renamed")

        registry.unregisterServer(providerID: testProviderID)
    }

    func test_keychainKeyFormat() {
        XCTAssertEqual(CredentialScope.plexAccount(accountID: "abc").keychainKey,
                       "plex.account.abc")
        XCTAssertEqual(CredentialScope.server(providerID: "plex:xyz").keychainKey,
                       "server.token.plex:xyz")
        XCTAssertEqual(CredentialScope.serverUser(providerID: "plex:xyz", userID: "u1").keychainKey,
                       "server.userToken.plex:xyz.u1")
    }
}
