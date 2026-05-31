//
//  PlexServerSelectionPolicy.swift
//  Rivulet
//
//  Deterministic Plex server identity and connection-selection helpers.
//

import Foundation

enum PlexServerSelectionPolicy {
    static func stableServerIdentifier(for server: PlexDevice) -> String {
        if let machineIdentifier = server.machineIdentifier, !machineIdentifier.isEmpty {
            return machineIdentifier
        }

        return server.clientIdentifier
    }

    static func providerID(for server: PlexDevice) -> String {
        "plex:\(stableServerIdentifier(for: server))"
    }

    static func matchingServer(
        in servers: [PlexDevice],
        savedIdentifier: String?,
        savedURL: String?,
        savedName: String?
    ) -> PlexDevice? {
        if let savedIdentifier, !savedIdentifier.isEmpty,
           let matchedServer = servers.first(where: { server in
               stableServerIdentifier(for: server) == savedIdentifier
                   || server.clientIdentifier == savedIdentifier
                   || server.machineIdentifier == savedIdentifier
           }) {
            return matchedServer
        }

        if let savedURL, !savedURL.isEmpty,
           let matchedServer = servers.first(where: { server in
               server.connections?.contains { $0.uri == savedURL } == true
           }) {
            return matchedServer
        }

        if let savedName, !savedName.isEmpty {
            let namedServers = servers.filter { $0.name == savedName }
            if namedServers.count == 1 {
                return namedServers[0]
            }
        }

        return nil
    }

    static func attachMachineIdentifiers(
        to devices: [PlexDevice],
        using lookup: [String: String]
    ) -> [PlexDevice] {
        devices.map { device in
            var mutableDevice = device
            if let machineIdentifier = lookup[device.clientIdentifier] ?? lookup[device.name] {
                mutableDevice.machineIdentifier = machineIdentifier
            }
            return mutableDevice
        }
    }

    static func machineIdentifierLookup(from data: Data) -> [String: String] {
        let records = serverRecords(from: data)
        let names = records.compactMap(\.name)
        let nameCounts = Dictionary(grouping: names, by: { $0 }).mapValues(\.count)

        var lookup: [String: String] = [:]
        for record in records {
            lookup[record.machineIdentifier] = record.machineIdentifier

            if let clientIdentifier = record.clientIdentifier, !clientIdentifier.isEmpty {
                lookup[clientIdentifier] = record.machineIdentifier
            }

            if let name = record.name, !name.isEmpty, nameCounts[name] == 1 {
                lookup[name] = record.machineIdentifier
            }
        }

        return lookup
    }

    static func orderedConnections(_ connections: [PlexConnection]) -> [PlexConnection] {
        connections
            .filter { !isDockerOrInternalAddress($0.address) }
            .sorted { lhs, rhs in
                let lhsScore = connectionScore(lhs)
                let rhsScore = connectionScore(rhs)
                if lhsScore != rhsScore {
                    return lhsScore > rhsScore
                }
                return lhs.uri < rhs.uri
            }
    }

    static func connectionScore(_ connection: PlexConnection) -> Int {
        var score = 0

        if !connection.relay {
            score += 1000
        }

        if connection.local {
            score += 500
            if connection.protocolType == "http" {
                score += 50
            }
        } else {
            if connection.protocolType == "https" {
                score += 100
            }
            if connection.address.contains(".plex.direct") {
                score += 50
            }
        }

        return score
    }

    static func buildPlexDirectURL(address: String, port: Int, machineIdentifier: String) -> String {
        let ipWithDashes = address.replacingOccurrences(of: ".", with: "-")
        return "https://\(ipWithDashes).\(machineIdentifier).plex.direct:\(port)"
    }

    static func isDockerOrInternalAddress(_ address: String) -> Bool {
        let dockerPrefixes = [
            "172.17.", "172.18.", "172.19.", "172.20.", "172.21.",
            "172.22.", "172.23.", "172.24.", "172.25.", "172.26.",
            "172.27.", "172.28.", "172.29.", "172.30.", "172.31.",
        ]

        let localhostAddresses = ["127.0.0.1", "localhost", "::1"]

        if dockerPrefixes.contains(where: address.hasPrefix) {
            return true
        }

        return localhostAddresses.contains(address)
    }

    private struct ServerRecord {
        let name: String?
        let clientIdentifier: String?
        let machineIdentifier: String
    }

    private static func serverRecords(from data: Data) -> [ServerRecord] {
        guard let xmlString = String(data: data, encoding: .utf8),
              let serverRegex = try? NSRegularExpression(pattern: #"<Server\b([^>]*)>"#) else {
            return []
        }

        let matches = serverRegex.matches(
            in: xmlString,
            range: NSRange(xmlString.startIndex..., in: xmlString)
        )

        return matches.compactMap { match in
            guard let attributesRange = Range(match.range(at: 1), in: xmlString) else {
                return nil
            }

            let attributes = attributes(from: String(xmlString[attributesRange]))
            guard let machineIdentifier = attributes["machineIdentifier"], !machineIdentifier.isEmpty else {
                return nil
            }

            return ServerRecord(
                name: attributes["name"],
                clientIdentifier: attributes["clientIdentifier"],
                machineIdentifier: machineIdentifier
            )
        }
    }

    private static func attributes(from string: String) -> [String: String] {
        guard let attributeRegex = try? NSRegularExpression(
            pattern: #"([A-Za-z_:][A-Za-z0-9_:.-]*)="([^"]*)""#
        ) else {
            return [:]
        }

        var attributes: [String: String] = [:]
        let matches = attributeRegex.matches(
            in: string,
            range: NSRange(string.startIndex..., in: string)
        )

        for match in matches {
            guard let nameRange = Range(match.range(at: 1), in: string),
                  let valueRange = Range(match.range(at: 2), in: string) else {
                continue
            }

            attributes[String(string[nameRange])] = String(string[valueRange])
        }

        return attributes
    }
}
