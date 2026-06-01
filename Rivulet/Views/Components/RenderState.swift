//
//  RenderState.swift
//  Rivulet
//
//  Epic 2 (E2-PR1) — shared, backend-agnostic render-state vocabulary for
//  data-backed surfaces (Home grid, Hero, Continue Watching, discovery rows).
//
//  This is foundation only. It does not redesign any surface. It formalizes the
//  loading / content / empty / error precedence that Home currently expresses as
//  an inline `if/else` ladder, so future Epic 2 work shares one deterministic
//  state model instead of re-deriving it per view.
//
//  Not Plex-specific: inputs are primitives (Bool / String / a generic payload),
//  so any provider or surface can reuse it.
//

import Foundation

/// Coarse phase of a data-backed surface, independent of its content payload.
///
/// Used for instrumentation, structured logging, and tests that assert state
/// transitions without caring about the concrete content value.
enum RenderStatePhase: String, Sendable, CaseIterable, Equatable {
    case loading
    case content
    case empty
    case error
}

/// Reusable representation of a data-backed surface's render state, generic over
/// the content payload so Hero, Continue Watching, discovery rows, and the Home
/// grid can share one state vocabulary without leaking provider specifics.
enum RenderState<Content> {
    case loading
    case content(Content)
    case empty
    case error(message: String)

    /// Payload-independent phase, for logging / signposts / transition tests.
    var phase: RenderStatePhase {
        switch self {
        case .loading: return .loading
        case .content: return .content
        case .empty: return .empty
        case .error: return .error
        }
    }

    /// The content payload, if this state is `.content`.
    var content: Content? {
        if case let .content(value) = self { return value }
        return nil
    }

    /// The error message, if this state is `.error`.
    var errorMessage: String? {
        if case let .error(message) = self { return message }
        return nil
    }

    var isLoading: Bool { phase == .loading }
}

extension RenderState: Sendable where Content: Sendable {}
extension RenderState: Equatable where Content: Equatable {}

/// Single source of precedence truth for resolving a `RenderState` from the raw
/// signals a surface exposes (a loading flag, an optional content payload, and
/// an optional error message).
///
/// Precedence — deliberately mirrors the legacy Home ladder in `PlexHomeView`
/// (`isLoadingHubs && hubs.isEmpty` → loading, then error, then empty, else
/// content): **content > loading > error > empty**. Content present always wins,
/// so a surface keeps showing existing content while it silently refreshes.
enum RenderStateResolver {
    static func resolve<Content>(
        isLoading: Bool,
        content: Content?,
        errorMessage: String?
    ) -> RenderState<Content> {
        if let content { return .content(content) }
        if isLoading { return .loading }
        if let errorMessage { return .error(message: errorMessage) }
        return .empty
    }
}
