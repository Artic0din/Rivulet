//
//  HomeRowOrderingPolicy.swift
//  Rivulet
//
//  E2-PR5 — deterministic Home content-row ordering. Continue Watching is the
//  most prominent content row (always first when it has items); the remaining
//  rows follow in the order supplied. Pure logic, unit-testable, no SwiftUI or
//  data-store coupling.
//

import Foundation

enum HomeRowOrderingPolicy {
    /// Returns home content rows with Continue Watching pinned first (when it has
    /// items), followed by `followingRows` in their given order. A nil or empty
    /// Continue Watching hub is omitted rather than shown empty.
    static func order(continueWatching: PlexHub?, followingRows: [PlexHub]) -> [PlexHub] {
        var result: [PlexHub] = []
        if let cw = continueWatching, cw.Metadata?.isEmpty == false {
            result.append(cw)
        }
        result.append(contentsOf: followingRows)
        return result
    }
}
