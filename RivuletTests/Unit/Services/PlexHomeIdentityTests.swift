//
//  PlexHomeIdentityTests.swift
//  RivuletTests
//
//  Tests for Plex Home profile identity and user-token ownership.
//

import XCTest
@testable import Rivulet

@MainActor
final class PlexHomeIdentityTests: XCTestCase {
    private var userDefaults: UserDefaults!
    private var suiteName: String!
    private let providerID = "plex:home-identity-test"

    override func setUp() async throws {
        try await super.setUp()
        suiteName = "PlexHomeIdentityTests.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        await clearCredentialState()
    }

    override func tearDown() async throws {
        KeychainHelper.deletePin(forUserUUID: protectedUser.uuid)
        KeychainHelper.deletePin(forUserUUID: managedUser.uuid)
        userDefaults.removePersistentDomain(forName: suiteName)
        await clearCredentialState()
        try await super.tearDown()
    }

    func testSuccessfulHomeUserSwitchUpdatesSelectedIdentityAndAppliesHomeUserServerToken() async {
        let network = MockPlexHomeProfileNetworkClient(
            homeUserToken: "home-user-plex-token",
            serverUserToken: "home-user-server-token"
        )
        let auth = MockPlexHomeAuthManager(
            accountToken: "account-token",
            selectedServerURL: "https://plex.example.test:32400",
            selectedServerToken: "selected-server-token"
        )
        let manager = makeManager(network: network, auth: auth)

        let switched = await manager.selectUser(managedUser, pin: nil)

        XCTAssertTrue(switched)
        XCTAssertEqual(manager.selectedUser, managedUser)
        XCTAssertEqual(auth.appliedHomeUserToken, "home-user-server-token")
        XCTAssertEqual(auth.appliedHomeUser, managedUser)
        XCTAssertEqual(network.switchRequests.last?.authToken, "account-token")
        XCTAssertEqual(network.switchRequests.last?.pin, nil)
        XCTAssertEqual(userDefaults.integer(forKey: "selectedPlexUserId"), managedUser.id)
        XCTAssertEqual(userDefaults.string(forKey: "selectedPlexUserUUID"), managedUser.uuid)
        XCTAssertNotEqual(auth.accountToken, auth.appliedHomeUserToken)
        XCTAssertNotEqual(auth.initialSelectedServerToken, auth.appliedHomeUserToken)
    }

    func testProtectedHomeUserSwitchUsesPinWithoutPersistingPinAutomatically() async {
        let network = MockPlexHomeProfileNetworkClient(
            homeUserToken: "protected-plex-token",
            serverUserToken: "protected-server-token"
        )
        let auth = MockPlexHomeAuthManager(
            accountToken: "account-token",
            selectedServerURL: "https://plex.example.test:32400",
            selectedServerToken: "selected-server-token"
        )
        let manager = makeManager(network: network, auth: auth)

        let switched = await manager.selectUser(protectedUser, pin: "2468")

        XCTAssertTrue(switched)
        XCTAssertEqual(network.switchRequests.last?.pin, "2468")
        XCTAssertEqual(auth.appliedHomeUserToken, "protected-server-token")
        XCTAssertFalse(manager.hasRememberedPin(for: protectedUser))
    }

    func testFailedHomeUserSwitchPreservesPriorIdentityAndTokenState() async {
        let network = MockPlexHomeProfileNetworkClient(
            homeUserToken: nil,
            serverUserToken: "should-not-apply"
        )
        let auth = MockPlexHomeAuthManager(
            accountToken: "account-token",
            selectedServerURL: "https://plex.example.test:32400",
            selectedServerToken: "selected-server-token"
        )
        let manager = makeManager(network: network, auth: auth)
        manager.selectedUser = adminUser
        userDefaults.set(adminUser.id, forKey: "selectedPlexUserId")
        userDefaults.set(adminUser.uuid, forKey: "selectedPlexUserUUID")
        userDefaults.set(adminUser.displayName, forKey: "selectedPlexUserName")

        let switched = await manager.selectUser(managedUser, pin: nil)

        XCTAssertFalse(switched)
        XCTAssertEqual(manager.selectedUser, adminUser)
        XCTAssertNil(auth.appliedHomeUserToken)
        XCTAssertEqual(auth.currentSelectedServerToken, "selected-server-token")
        XCTAssertEqual(userDefaults.integer(forKey: "selectedPlexUserId"), adminUser.id)
        XCTAssertEqual(userDefaults.string(forKey: "selectedPlexUserUUID"), adminUser.uuid)
    }

    func testRememberedPinFailureClearsStoredPinAndPreservesPriorState() async {
        let network = MockPlexHomeProfileNetworkClient(
            homeUserToken: nil,
            serverUserToken: nil
        )
        let auth = MockPlexHomeAuthManager(
            accountToken: "account-token",
            selectedServerURL: "https://plex.example.test:32400",
            selectedServerToken: "selected-server-token"
        )
        let manager = makeManager(network: network, auth: auth)
        manager.rememberPin("2468", for: protectedUser)
        XCTAssertTrue(manager.hasRememberedPin(for: protectedUser))

        let result = await manager.selectUserWithRememberedPin(protectedUser)

        XCTAssertFalse(result.success)
        XCTAssertTrue(result.pinWasInvalid)
        XCTAssertFalse(manager.hasRememberedPin(for: protectedUser))
        XCTAssertNil(auth.appliedHomeUserToken)
    }

    func testProfileResetClearsSelectedProfileAndRememberedPins() {
        let manager = makeManager()
        manager.selectedUser = protectedUser
        manager.rememberPin("2468", for: protectedUser)
        manager.homeUsers = []
        userDefaults.set(protectedUser.id, forKey: "selectedPlexUserId")
        userDefaults.set(protectedUser.uuid, forKey: "selectedPlexUserUUID")
        userDefaults.set(protectedUser.displayName, forKey: "selectedPlexUserName")

        manager.reset()

        XCTAssertTrue(manager.homeUsers.isEmpty)
        XCTAssertNil(manager.selectedUser)
        XCTAssertFalse(manager.hasRememberedPin(for: protectedUser))
        XCTAssertNil(userDefaults.object(forKey: "selectedPlexUserId"))
        XCTAssertNil(userDefaults.string(forKey: "selectedPlexUserUUID"))
        XCTAssertNil(userDefaults.string(forKey: "selectedPlexUserName"))
    }

    private func makeManager() -> PlexUserProfileManager {
        makeManager(network: MockPlexHomeProfileNetworkClient(), auth: MockPlexHomeAuthManager())
    }

    private func makeManager(
        network: MockPlexHomeProfileNetworkClient,
        auth: MockPlexHomeAuthManager
    ) -> PlexUserProfileManager {
        PlexUserProfileManager(
            networkClient: network,
            authManager: auth,
            userDefaults: userDefaults,
            profileSwitchHandler: { _, _ in }
        )
    }

    private func clearCredentialState() async {
        CredentialRegistry.shared.unregisterServer(providerID: providerID)
        await CredentialRegistry.shared.clearToken(for: .server(providerID: providerID))
        await CredentialRegistry.shared.clearToken(for: .serverUser(providerID: providerID, userID: managedUser.uuid))
        await CredentialRegistry.shared.clearToken(for: .serverUser(providerID: providerID, userID: protectedUser.uuid))
    }

    private var adminUser: PlexHomeUser {
        PlexHomeUser(id: 1, uuid: "admin-user", title: "Admin", admin: true)
    }

    private var managedUser: PlexHomeUser {
        PlexHomeUser(id: 2, uuid: "managed-user", title: "Managed", admin: false, restricted: true)
    }

    private var protectedUser: PlexHomeUser {
        PlexHomeUser(id: 3, uuid: "protected-user", title: "Protected", admin: false, restricted: true, protected: true)
    }
}

@MainActor
private final class MockPlexHomeAuthManager: PlexHomeAuthManaging {
    let accountToken: String?
    let selectedServerURL: String?
    let initialSelectedServerToken: String?
    private(set) var currentSelectedServerToken: String?
    private(set) var appliedHomeUserToken: String?
    private(set) var appliedHomeUser: PlexHomeUser?

    init(
        accountToken: String? = "account-token",
        selectedServerURL: String? = "https://plex.example.test:32400",
        selectedServerToken: String? = "selected-server-token"
    ) {
        self.accountToken = accountToken
        self.selectedServerURL = selectedServerURL
        self.initialSelectedServerToken = selectedServerToken
        self.currentSelectedServerToken = selectedServerToken
    }

    var authToken: String? {
        accountToken
    }

    func applyHomeUserServerToken(_ token: String, for user: PlexHomeUser) async {
        currentSelectedServerToken = token
        appliedHomeUserToken = token
        appliedHomeUser = user
    }
}

private final class MockPlexHomeProfileNetworkClient: PlexHomeProfileNetworkClient {
    struct SwitchRequest: Equatable {
        let userUUID: String
        let pin: String?
        let authToken: String
    }

    var homeUsers: [PlexHomeUser]
    var homeUserToken: String?
    var serverUserToken: String?
    var switchError: Error?
    private(set) var switchRequests: [SwitchRequest] = []

    init(
        homeUsers: [PlexHomeUser] = [],
        homeUserToken: String? = "home-user-plex-token",
        serverUserToken: String? = "home-user-server-token",
        switchError: Error? = nil
    ) {
        self.homeUsers = homeUsers
        self.homeUserToken = homeUserToken
        self.serverUserToken = serverUserToken
        self.switchError = switchError
    }

    func getHomeUsers(authToken _: String) async throws -> [PlexHomeUser] {
        homeUsers
    }

    func switchToHomeUser(userUUID: String, pin: String?, authToken: String) async throws -> String? {
        switchRequests.append(SwitchRequest(userUUID: userUUID, pin: pin, authToken: authToken))
        if let switchError {
            throw switchError
        }
        return homeUserToken
    }

    func getServerAccessToken(authToken _: String, serverURL _: String) async -> String? {
        serverUserToken
    }
}
