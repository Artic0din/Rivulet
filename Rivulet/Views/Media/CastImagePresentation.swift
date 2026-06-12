//
//  CastImagePresentation.swift
//  Rivulet
//
//  E3-PR11 — cast/crew presentation helpers (pure, tested).
//
//  `PersonCard` already loads real cast/crew images through the safe
//  `CachedAsyncImage` pipeline with token handling. This adds the pure pieces:
//  a combined VoiceOver label (name + role) and an initials fallback for when no
//  image is available — so a person cell never renders a broken/empty avatar and
//  always exposes the name to VoiceOver. No new metadata provider; image URLs
//  come from existing Plex/mapper data.
//

import Foundation

nonisolated enum CastImagePresentation {
    /// Combined VoiceOver label: "Name, Role" (role omitted when empty).
    static func accessibilityLabel(name: String, role: String?) -> String {
        if let role = role?.trimmingCharacters(in: .whitespacesAndNewlines), !role.isEmpty {
            return "\(name), \(role)"
        }
        return name
    }

    /// Up to two uppercase initials from a person's name; "?" when empty.
    static func initials(from name: String) -> String {
        let words = name
            .split(whereSeparator: { $0 == " " })
            .prefix(2)
        let letters = words.compactMap { $0.first }.map { String($0).uppercased() }
        return letters.isEmpty ? "?" : letters.joined()
    }
}
