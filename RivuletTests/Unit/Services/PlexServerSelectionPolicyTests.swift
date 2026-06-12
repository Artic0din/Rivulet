//
//  PlexServerSelectionPolicyTests.swift
//  RivuletTests
//
//  Tests for deterministic Plex multi-server identity and connection selection.
//

import XCTest
@testable import Rivulet

final class PlexServerSelectionPolicyTests: XCTestCase {
    func testMachineIdentifierLookupDoesNotUseDuplicateNamesAsStableKeys() {
        let xml = """
        <MediaContainer>
            <Server name="Shared Library" machineIdentifier="machine-alpha" />
            <Server name="Shared Library" machineIdentifier="machine-beta" />
            <Server name="Unique Library" machineIdentifier="machine-gamma" />
        </MediaContainer>
        """

        let lookup = PlexServerSelectionPolicy.machineIdentifierLookup(from: Data(xml.utf8))

        XCTAssertNil(lookup["Shared Library"])
        XCTAssertEqual(lookup["Unique Library"], "machine-gamma")
        XCTAssertEqual(lookup["machine-alpha"], "machine-alpha")
        XCTAssertEqual(lookup["machine-beta"], "machine-beta")
    }

    func testAttachMachineIdentifiersPrefersClientIdentifierBeforeName() throws {
        let devices = [
            try makeServer(name: "Shared Library", clientIdentifier: "machine-alpha"),
            try makeServer(name: "Shared Library", clientIdentifier: "machine-beta"),
            try makeServer(name: "Unique Library", clientIdentifier: "resource-gamma")
        ]
        let xml = """
        <MediaContainer>
            <Server name="Shared Library" machineIdentifier="machine-alpha" />
            <Server name="Shared Library" machineIdentifier="machine-beta" />
            <Server name="Unique Library" machineIdentifier="machine-gamma" />
        </MediaContainer>
        """

        let resolved = PlexServerSelectionPolicy.attachMachineIdentifiers(
            to: devices,
            using: PlexServerSelectionPolicy.machineIdentifierLookup(from: Data(xml.utf8))
        )

        XCTAssertEqual(resolved[0].machineIdentifier, "machine-alpha")
        XCTAssertEqual(resolved[1].machineIdentifier, "machine-beta")
        XCTAssertEqual(resolved[2].machineIdentifier, "machine-gamma")
    }

    func testMatchingServerUsesSavedIdentifierBeforeDuplicateDisplayName() throws {
        let alpha = try makeServer(name: "Shared Library", clientIdentifier: "resource-alpha", machineIdentifier: "machine-alpha")
        let beta = try makeServer(name: "Shared Library", clientIdentifier: "resource-beta", machineIdentifier: "machine-beta")

        let matched = PlexServerSelectionPolicy.matchingServer(
            in: [alpha, beta],
            savedIdentifier: "machine-beta",
            savedURL: nil,
            savedName: "Shared Library"
        )

        XCTAssertEqual(matched?.clientIdentifier, "resource-beta")
    }

    func testMatchingServerDoesNotUseAmbiguousDuplicateDisplayName() throws {
        let alpha = try makeServer(name: "Shared Library", clientIdentifier: "resource-alpha", machineIdentifier: "machine-alpha")
        let beta = try makeServer(name: "Shared Library", clientIdentifier: "resource-beta", machineIdentifier: "machine-beta")

        let matched = PlexServerSelectionPolicy.matchingServer(
            in: [alpha, beta],
            savedIdentifier: nil,
            savedURL: nil,
            savedName: "Shared Library"
        )

        XCTAssertNil(matched)
    }

    func testMatchingServerFallsBackToUniqueDisplayName() throws {
        let shared = try makeServer(name: "Shared Library", clientIdentifier: "resource-alpha", machineIdentifier: "machine-alpha")
        let unique = try makeServer(name: "Unique Library", clientIdentifier: "resource-beta", machineIdentifier: "machine-beta")

        let matched = PlexServerSelectionPolicy.matchingServer(
            in: [shared, unique],
            savedIdentifier: nil,
            savedURL: nil,
            savedName: "Unique Library"
        )

        XCTAssertEqual(matched?.clientIdentifier, "resource-beta")
    }

    func testOrderedConnectionsAreDeterministicAndPreferLocalRemoteRelay() {
        let connections = [
            makeConnection(protocolType: "https", address: "relay.plex.tv", uri: "https://relay.plex.tv:443", local: false, relay: true),
            makeConnection(protocolType: "https", address: "remote.example.com", uri: "https://remote.example.com:32400", local: false, relay: false),
            makeConnection(protocolType: "http", address: "192.168.1.10", uri: "http://192.168.1.10:32400", local: true, relay: false),
            makeConnection(protocolType: "http", address: "172.17.0.2", uri: "http://172.17.0.2:32400", local: true, relay: false)
        ]

        let ordered = PlexServerSelectionPolicy.orderedConnections(connections).map(\.uri)

        XCTAssertEqual(ordered, [
            "http://192.168.1.10:32400",
            "https://remote.example.com:32400",
            "https://relay.plex.tv:443"
        ])
    }

    func testStableServerIdentifierUsesMachineIdentifierBeforeClientIdentifier() throws {
        let withMachine = try makeServer(name: "Primary", clientIdentifier: "resource-alpha", machineIdentifier: "machine-alpha")
        let withoutMachine = try makeServer(name: "Secondary", clientIdentifier: "resource-beta", machineIdentifier: nil)

        XCTAssertEqual(PlexServerSelectionPolicy.stableServerIdentifier(for: withMachine), "machine-alpha")
        XCTAssertEqual(PlexServerSelectionPolicy.stableServerIdentifier(for: withoutMachine), "resource-beta")
        XCTAssertEqual(PlexServerSelectionPolicy.providerID(for: withMachine), "plex:machine-alpha")
    }

    private func makeServer(
        name: String,
        clientIdentifier: String,
        machineIdentifier: String? = nil,
        accessToken: String? = nil,
        connections: [Rivulet.PlexConnection]? = nil
    ) throws -> Rivulet.PlexDevice {
        let connectionJSON = try (connections ?? []).map { connection in
            """
            {
              "protocol": "\(connection.protocolType)",
              "address": "\(connection.address)",
              "port": \(connection.port),
              "uri": "\(connection.uri)",
              "local": \(connection.local),
              "relay": \(connection.relay),
              "IPv6": \(connection.IPv6)
            }
            """
        }.joined(separator: ",")
        let accessTokenJSON = accessToken.map { #","accessToken": "\#($0)""# } ?? ""
        let json = """
        {
          "name": "\(name)",
          "product": "Plex Media Server",
          "productVersion": "1.40.0",
          "platform": "macOS",
          "platformVersion": "14.0",
          "device": "Mac",
          "clientIdentifier": "\(clientIdentifier)",
          "createdAt": "2024-01-01T00:00:00Z",
          "lastSeenAt": "2024-01-02T00:00:00Z",
          "provides": "server",
          "owned": true,
          "home": false,
          "synced": false,
          "relay": false,
          "presence": true,
          "httpsRequired": false,
          "publicAddressMatches": true,
          "connections": [\(connectionJSON)]
          \(accessTokenJSON)
        }
        """
        var device = try JSONDecoder().decode(Rivulet.PlexDevice.self, from: Data(json.utf8))
        device.machineIdentifier = machineIdentifier
        return device
    }

    private func makeConnection(
        protocolType: String,
        address: String,
        uri: String,
        local: Bool,
        relay: Bool
    ) -> Rivulet.PlexConnection {
        let json = """
        {
          "protocol": "\(protocolType)",
          "address": "\(address)",
          "port": 32400,
          "uri": "\(uri)",
          "local": \(local),
          "relay": \(relay),
          "IPv6": false
        }
        """
        return try! JSONDecoder().decode(Rivulet.PlexConnection.self, from: Data(json.utf8))
    }
}
