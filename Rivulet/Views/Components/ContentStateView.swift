//
//  ContentStateView.swift
//  Rivulet
//
//  Epic 2 (E2-PR1) — shared state-view surface for data-backed screens.
//
//  Architecture only. This renders the loading / empty / error / content
//  presentations a surface needs, keyed off `RenderStatePhase`, so views stop
//  hand-rolling these states inline. Default presentations are byte-for-byte
//  equivalents of the existing `PlexHomeView` loading/empty/error views — this
//  PR introduces NO visual redesign. Later Epic 2 PRs restyle here, once, and
//  every consumer inherits it.
//
//  Accessibility (Epic 0 A11Y matrix): each non-content state is a combined
//  VoiceOver element with a meaningful label; the retry control is focusable
//  with a deterministic initial focus and an explicit label/hint; presentation
//  is static and motion-free so Reduce Motion has nothing to suppress.
//

import SwiftUI

/// Declarative description of a non-content state (empty / error) presentation.
struct ContentStatePresentation: Equatable {
    let systemImage: String
    let title: String
    /// Static message. For error states the live error string is passed
    /// separately to `ContentStateView` and takes precedence over this.
    let message: String
    let actionTitle: String?

    /// Matches the legacy `PlexHomeView.emptyView`.
    static let homeEmpty = ContentStatePresentation(
        systemImage: "film.stack",
        title: "No Content",
        message: "Your Plex library appears to be empty.",
        actionTitle: "Refresh"
    )

    /// Matches the legacy `PlexHomeView.errorView` (live message injected).
    static let homeError = ContentStatePresentation(
        systemImage: "exclamationmark.triangle",
        title: "Unable to Load",
        message: "",
        actionTitle: "Try Again"
    )
}

/// Renders a data-backed surface across its render-state phases with one shared,
/// accessible, tvOS-friendly surface. Pass the resolved `phase` plus a content
/// builder; non-content states use overridable presentations.
struct ContentStateView<ContentBody: View>: View {
    let phase: RenderStatePhase
    var errorMessage: String?
    var loadingLabel: String
    var empty: ContentStatePresentation
    var error: ContentStatePresentation
    var onRetry: (() -> Void)?
    @ViewBuilder var content: () -> ContentBody

    init(
        phase: RenderStatePhase,
        errorMessage: String? = nil,
        loadingLabel: String = "Loading",
        empty: ContentStatePresentation = .homeEmpty,
        error: ContentStatePresentation = .homeError,
        onRetry: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> ContentBody
    ) {
        self.phase = phase
        self.errorMessage = errorMessage
        self.loadingLabel = loadingLabel
        self.empty = empty
        self.error = error
        self.onRetry = onRetry
        self.content = content
    }

    @FocusState private var actionFocused: Bool

    var body: some View {
        switch phase {
        case .content:
            content()
        case .loading:
            loadingState
        case .empty:
            messageState(empty, message: empty.message)
        case .error:
            messageState(error, message: errorMessage ?? error.message)
        }
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)
            Text(loadingLabel)
                .font(.title3)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(loadingLabel)
        .accessibilityAddTraits(.isStaticText)
    }

    @ViewBuilder
    private func messageState(_ presentation: ContentStatePresentation, message: String) -> some View {
        VStack(spacing: 24) {
            Image(systemName: presentation.systemImage)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.secondary)

            Text(presentation.title)
                .font(.title2)
                .fontWeight(.medium)

            if !message.isEmpty {
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }

            if let actionTitle = presentation.actionTitle, let onRetry {
                Button {
                    onRetry()
                } label: {
                    Text(actionTitle)
                        .fontWeight(.medium)
                }
                .buttonStyle(AppStoreButtonStyle())
                .focused($actionFocused)
                .accessibilityLabel(actionTitle)
                .accessibilityHint("\(presentation.title). Activates to retry.")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Combine the descriptive text into one VoiceOver element; the action
        // button stays a separate, operable element.
        .accessibilityElement(children: .contain)
        .onAppear {
            // Deterministic initial focus: the retry control is the sole focus
            // target in these states, but make it explicit rather than implicit.
            if presentation.actionTitle != nil && onRetry != nil {
                actionFocused = true
            }
        }
    }
}
