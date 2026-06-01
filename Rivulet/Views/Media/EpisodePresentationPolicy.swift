//
//  EpisodePresentationPolicy.swift
//  Rivulet
//
//  E3-PR10 — episode-card presentation helpers.
//
//  Pure, `nonisolated`, unit-testable presentation helpers for the live episode
//  card (label + combined VoiceOver summary). All inputs are already-resolved
//  presentation values, so nothing here touches playback, watch-state, or any
//  provider.
//
//  NOTE (ADO-03): the former `ScheduleLabel`/`ScheduleLabelPolicy` (the narrow
//  New/Recently Added/Season Finale tagger) was retired here and superseded by
//  the broader, future-proof Content Status Label System in
//  `Views/Components/ContentStatusLabel.swift`. There is intentionally one
//  status system, not two.
//

import Foundation

// MARK: - Episode card presentation

// ADO-01B: the standalone `EpisodeContentCard` view and its `EpisodeCardModel`
// were retired — the production `EpisodeCard` (in `MediaDetailView`) is the live,
// richer episode card and consumes the resolved-values helpers below directly.
nonisolated enum EpisodeCardPresentation {
    /// "EPISODE 13" (uppercase, Apple-TV-style), or "EPISODE" when index absent.
    static func episodeLabel(index: Int?) -> String {
        if let index { return "EPISODE \(index)" }
        return "EPISODE"
    }

    /// Combined VoiceOver label for an episode card: episode number, title,
    /// runtime, and state. Used live by the production `EpisodeCard`, which works
    /// in agnostic `MediaItem` terms (already-formatted runtime + progress).
    /// `episodeLabel` is presented as-is (capitalized) so an "S06E13"-style
    /// prefix label reads naturally too.
    static func accessibilityLabel(
        episodeLabel: String,
        title: String,
        runtime: String?,
        isWatched: Bool,
        progress: Double?
    ) -> String {
        var parts: [String] = [episodeLabel.capitalized, title]
        if let runtime { parts.append(runtime) }
        if isWatched {
            parts.append("Watched")
        } else if let progress {
            parts.append("\(Int(progress * 100)) percent watched")
        }
        return parts.joined(separator: ", ")
    }
}
